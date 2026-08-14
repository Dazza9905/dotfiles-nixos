{
  flake.nixosModules.immich = {...}: {
    services.immich = {
      enable = true;
      host = "0.0.0.0"; # reachable over LAN + netbird
      port = 2283;
      openFirewall = true;
      # Same path the docker stack used, so the existing library and the B2
      # mirror layout stay valid without moving anything.
      mediaLocation = "/mnt/nas-data/immich-app/data";
    };

    # Postgres does constant small writes; keep it off the SD card.
    services.postgresql.dataDir = "/mnt/nas-data/postgres";
    systemd.tmpfiles.rules = [
      "d /mnt/nas-data/postgres 0700 postgres postgres - -"
    ];

    # /mnt/nas-data is mounted nofail — never let these units run (or postgres
    # initdb onto the SD card) when the data disk is missing.
    systemd.services.postgresql.unitConfig.RequiresMountsFor = ["/mnt/nas-data"];
    systemd.services.immich-server.unitConfig.RequiresMountsFor = ["/mnt/nas-data"];

    services.immich-public-proxy = {
      enable = true;
      immichUrl = "http://localhost:2283";
      port = 3000; # TODO: match whatever port the docker proxy published
      openFirewall = true;
    };
  };
}
