# newt: the home-side half of the pangolin tunnel. Dials OUT to the VPS, so the
# rpi5 needs no port forwards and nothing inbound on the home network.
#
# The blueprint makes proxy resources declarative instead of click-ops in the
# pangolin dashboard, so what is reachable from the internet is reviewable here.
{
  flake.nixosModules.newt = {config, ...}: {
    services.newt = {
      enable = true;
      environmentFile = config.sops.secrets.newt_env.path;

      settings = {
        endpoint = "https://pangolin.dazza9905.me";
        log-level = "INFO";
      };

      blueprint.proxy-resources.immich-share = {
        name = "Immich Shared Albums";
        protocol = "http";
        # TODO: add a DNS A record for this once you're ready to deploy newt
        full-domain = "photos.dazza9905.me";
        targets = [
          {
            hostname = "localhost";
            method = "http";
            port = 3000; # immich-public-proxy, same host
          }
        ];
        # Share links are handed to people who have no pangolin account, so
        # pangolin's own SSO gate has to stay off. IPP is the access control:
        # it only ever serves assets that have a live share link.
        auth.sso-enabled = false;
      };
    };

    # NEWT_ID / NEWT_SECRET, issued when you create the site in the pangolin
    # dashboard. The module asserts environmentFile is set, so this cannot be
    # forgotten silently.
    sops.secrets.newt_env = {};
  };
}
