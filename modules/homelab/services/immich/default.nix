{
  config,
  lib,
  pkgs,
  ...
}:
let
  homelab = config.homelab;
  cfg = homelab.services.immich;
in
{
# =======================================================
# IMPORTS
# =======================================================
# =======================================================
# OPTIONS
# =======================================================
  options.homelab.services.immich = {
    enable = lib.mkEnableOption "Enable Immich";
    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "${homelab.mount}/immich-app/data";
    };
    ipp = lib.mkEnableOption "Enable Immich Public Proxy";

  };
# =======================================================
# CONFIG
# =======================================================
  config = lib.mkIf cfg.enable {

    services.immich = {
      enable = true;
      host = "0.0.0.0";
      group = homelab.group;
      port = 2283;
      mediaLocation = cfg.mediaDir;

    };
    services.immich-public-proxy = {
      enable = cfg.ipp;
      immichUrl = "http://192.168.100.21:2283";
      openFirewall = true;
      settings = {
        ipp = {
          downloadOriginalPhoto = true;
          downloadedFilename = 0;
          allowDownloadAll = 1;
          downloadFromImmichConcurrencyLimit = 2;

          gallery = {
            singleImage = true;
            singleItemAutoOpen = true;
            showTitle = true;
            showDescription = true;
            groupByDate = true;
          };

          lightbox = {
            showDownload = false;
            showArrows = true;
            mobileArrows = true;

            options = {
              autoPlayVideos = true;
              bgOpacity = 0.85;
            };
          };

          showMetadata = {
            description = {
              caption = false;
              sidebar = true;
            };

            exif = {
              enabled = true;
              dateTimeOriginal = true;
              make = true;
              model = true;
              lensModel = true;
              exposureTime = true;
              iso = true;
              fNumber = true;
              focalLength = true;
            };

            location = {
              enabled = true;
              city = true;
              state = true;
              country = true;
            };
          };
        };
      };
    };

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 2283 ];
    };

  };

 #    # `earthdistance` is database state, not a PostgreSQL package option.  Keep
 #    # it convergent with the system configuration, and ensure Immich never
 #    # starts before the extensions it needs are available.  `earthdistance`
 #    # depends on `cube`.
 #    systemd.services.immich-postgresql-extensions = {
 #      description = "Provision PostgreSQL extensions required by Immich";
 #      after = [ "postgresql.target" ];
 #      requiredBy = [ "immich-server.service" ];
 #      before = [ "immich-server.service" ];
 #
 #      serviceConfig = {
 #        Type = "oneshot";
 #        User = "postgres";
 #      };
 #
 #      path = [ config.services.postgresql.package ];
 #      script = ''
 #        psql --dbname=immich --set=ON_ERROR_STOP=1 <<'SQL'
 #        CREATE EXTENSION IF NOT EXISTS cube;
 #        CREATE EXTENSION IF NOT EXISTS earthdistance;
 #        SQL
 #      '';
 #    };
 #
 #    networking.firewall = {
 #      enable = true;
 #      allowedTCPPorts = [ 2283 ];
 #    };
 #
 #  };
 #
 # gzip -dc /mnt/860evo/immich-app/data/backups/immich-db-backup-20260817T020000-v3.1.0-pg14.18.sql.gz | sudo -u postgres psql -v ON_ERROR_STOP=1 -d immich
}
