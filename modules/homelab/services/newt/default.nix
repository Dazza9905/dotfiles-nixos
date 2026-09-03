{
  config,
  lib,
  pkgs,
  ...
}:
let
  homelab = config.homelab;
  cfg = homelab.services.newt;
in
{
# =======================================================
# IMPORTS
# =======================================================
# =======================================================
# OPTIONS
# =======================================================
  options.homelab.services.newt = {
    enable = lib.mkEnableOption "Enable Newt";
    environmentFile = lib.mkOption {
      type = lib.types.path;
      default = config.sops.templates."newt.env".path;
    };
    endpoint = lib.mkOption {
      type = lib.types.str;
      default = "https://pangolin.dazza9905.me";
    };

  };
# =======================================================
# CONFIG
# =======================================================
  config = lib.mkIf cfg.enable {
    services.newt = {
      enable = true;
      settings = {
          endpoint = cfg.endpoint;
      };
      environmentFile = config.sops.templates."newt.env".path;
    };

    # =======================================================
    # SOPS
    # =======================================================
    sops.secrets."services/newt/id" = {};
    sops.secrets."services/newt/secret" = {};
    sops.templates."newt.env".content = ''
      NEWT_ID=${config.sops.placeholder."services/newt/id"}
      NEWT_SECRET=${config.sops.placeholder."services/newt/secret"}
    '';

  };

}
