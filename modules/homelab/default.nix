{ self, inputs, ... }: {
  flake.nixosModules.homelab = { lib, config, ... }:
  {
# =======================================================
# IMPORTS
# =======================================================
    imports = [
      ./services
    ];
# =======================================================
# OPTIONS
# =======================================================
    options.homelab = {
      enable = lib.mkEnableOption "machine and services configuration for homelab stuff";
      
      mount = lib.mkOption {
        default = "/mnt/nas";
        type = lib.types.str;
        description = "path to the main mount";
      };
      user = lib.mkOption {
        default = "homelab";
        type = lib.types.str;
        description = "user under which services run";
      };
      group = lib.mkOption {
        default = "homelab";
        type = lib.types.str;
        description = "group under which services run";
      };
      timeZone = lib.mkOption {
        default = "Europe/Bratislava";
        type = lib.types.str;
        description = "time zone for services";
      };
      baseDomain = lib.mkOption {
        default = "";
        type = lib.types.str;
        description = "baseDomain";
      };
    };
# =======================================================
# CONFIG
# =======================================================
    config = lib.mkIf config.homelab.enable {
      users = {
        groups.${config.homelab.group} = {
          gid = 950;
        };
        users.${config.homelab.user} = {
          uid = 950;
          isSystemUser = true;
          group = config.homelab.group;
        };
      };
    };
  };
}
