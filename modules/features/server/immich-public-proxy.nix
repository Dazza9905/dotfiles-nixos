# Split out from the immich module so the placement decision stays visible:
# this deliberately runs on the SAME host as immich, not on the VPS.
#
# IPP needs a full-API connection to immich to resolve share links. Keeping the
# two on one host means that connection never leaves loopback, and immich itself
# needs no route from the internet at all — the VPS only ever reaches IPP, which
# can only serve content that has an active share link.
{
  flake.nixosModules.immich-public-proxy = {...}: {
    services.immich-public-proxy = {
      enable = true;
      immichUrl = "http://localhost:2283";
      port = 3000;
      # newt runs on this same host and dials localhost:3000, so nothing outside
      # the box ever connects directly — no firewall hole required.
      openFirewall = false;
    };
  };
}
