{
  flake.nixosModules.backup = {
    config,
    lib,
    pkgs,
    ...
  }: let
    bucket = "bb-b2:dazza9905-nas-data";

    # Shared by both jobs: restic snapshots go through rclone, so the single
    # sops-managed rclone.conf is the only B2 credential.
    backupEnv = {
      RCLONE_CONFIG = config.sops.secrets.rclone_conf.path;
      RESTIC_REPOSITORY = "rclone:${bucket}/restic";
      RESTIC_PASSWORD_FILE = config.sops.secrets.restic_password.path;
    };

    commonInputs = [pkgs.rclone pkgs.restic pkgs.util-linux];

    immichBackup = pkgs.writeShellApplication {
      name = "immich-backup";
      runtimeInputs = commonInputs ++ [pkgs.gzip config.services.postgresql.package];
      text = ''
        # /mnt/nas-data is nofail: syncing an empty mountpoint would wipe the
        # B2 mirror, so hard-refuse to run without the disk.
        if ! mountpoint -q /mnt/nas-data; then
          echo "ERROR: /mnt/nas-data is not mounted, refusing to run" >&2
          exit 1
        fi

        rclone_flags=(--transfers 32 --checkers 32 --fast-list --b2-chunk-size 64M --b2-upload-cutoff 64M)
        ts=$(date +%Y-%m-%d_%H-%M-%S)
        dumpdir=/mnt/nas-data/immich-app/db-dumps
        mkdir -p "$dumpdir"

        echo "Dumping postgres (immich still running; dump is transactional)..."
        runuser -u postgres -- pg_dumpall --clean --if-exists | gzip -9 \
          > "$dumpdir/immich-db-$ts.sql.gz"

        echo "Stopping immich for file-level consistency..."
        systemctl stop immich-server.service immich-machine-learning.service
        trap 'systemctl start immich-server.service immich-machine-learning.service' EXIT

        echo "Creating restic snapshot..."
        restic backup --retry-lock 1h --tag immich \
          /mnt/nas-data/immich-app/data "$dumpdir"

        echo "Syncing rclone mirror..."
        rclone sync /mnt/nas-data/immich-app/data "${bucket}/immich/data" \
          --backup-dir "${bucket}/immich/deleted-data/$ts" \
          "''${rclone_flags[@]}"

        echo "Restarting immich..."
        systemctl start immich-server.service immich-machine-learning.service
        trap - EXIT

        echo "Uploading DB dumps..."
        rclone copy "$dumpdir" "${bucket}/immich/db-dumps" "''${rclone_flags[@]}"

        echo "Pruning old dumps and deleted files..."
        rclone delete "${bucket}/immich/db-dumps" --min-age 14d
        find "$dumpdir" -name '*.sql.gz' -mtime +14 -delete
        # immich's own in-app dump dir is redundant with our pg_dumpall
        rclone purge "${bucket}/immich/data/backups" 2>/dev/null \
          || echo "no data/backups to remove"
        rclone delete "${bucket}/immich/deleted-data" --min-age 14d
        rclone rmdirs "${bucket}/immich/deleted-data" --leave-root 2>/dev/null || true

        echo "Applying restic retention policy..."
        restic forget --retry-lock 1h --tag immich --group-by tags \
          --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune

        echo "Immich backup completed successfully."
      '';
    };

    dataBackup = pkgs.writeShellApplication {
      name = "data-backup";
      runtimeInputs = commonInputs;
      text = ''
        if ! mountpoint -q /mnt/nas-data; then
          echo "ERROR: /mnt/nas-data is not mounted, refusing to run" >&2
          exit 1
        fi

        rclone_flags=(--transfers 32 --checkers 32 --fast-list --b2-chunk-size 64M --b2-upload-cutoff 64M)
        ts=$(date +%Y-%m-%d_%H-%M-%S)

        for d in files-dazza files-patrik; do
          echo "Syncing $d mirror..."
          rclone sync "/mnt/nas-data/$d" "${bucket}/$d" \
            --backup-dir "${bucket}/files-deleted/$d/$ts" \
            "''${rclone_flags[@]}"
        done

        restic_paths=(/mnt/nas-data/files-dazza /mnt/nas-data/files-patrik)
        if [ -d /opt/stacks ]; then
          echo "Syncing docker compose files..."
          rclone sync /opt/stacks "${bucket}/docker-compose-files" \
            "''${rclone_flags[@]}"
          restic_paths+=(/opt/stacks)
        fi

        echo "Creating restic snapshot..."
        restic backup --retry-lock 1h --tag files "''${restic_paths[@]}"

        echo "Pruning old deleted files..."
        rclone delete "${bucket}/files-deleted" --min-age 14d
        rclone rmdirs "${bucket}/files-deleted" --leave-root 2>/dev/null || true

        echo "Applying restic retention policy..."
        restic forget --retry-lock 1h --tag files --group-by tags \
          --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune

        echo "Data backup completed successfully."
      '';
    };
  in {
    sops.secrets.rclone_conf = {}; # root:root 0400 — jobs run as root
    sops.secrets.restic_password = {};

    # For manual ops: restic init, restic snapshots, restore, ...
    environment.systemPackages = [pkgs.restic pkgs.rclone];

    systemd.services.immich-backup = {
      description = "Immich DB dump + restic/rclone backup to B2";
      environment = backupEnv;
      unitConfig.RequiresMountsFor = ["/mnt/nas-data"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe immichBackup;
      };
    };
    systemd.timers.immich-backup = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "02:00";
        Persistent = true; # missed runs fire on next boot
      };
    };

    systemd.services.data-backup = {
      description = "NAS shares + compose files restic/rclone backup to B2";
      environment = backupEnv;
      # only ordering: if both are queued (Persistent catch-up after downtime),
      # run after the immich job instead of fighting it for the repo lock
      after = ["immich-backup.service"];
      unitConfig.RequiresMountsFor = ["/mnt/nas-data"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe dataBackup;
      };
    };
    systemd.timers.data-backup = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "03:00";
        Persistent = true;
      };
    };
  };
}
