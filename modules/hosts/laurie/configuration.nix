{self, ...}: {
  flake.nixosModules.laurieConfiguration = {
    lib,
    pkgs,
    ...
  }: {
    imports = [
      self.nixosModules.laurieHardware
      self.nixosModules.pangolin-docker
    ];

    networking.hostName = "laurie";

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "prohibit-password";
      };
    };
    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINt6vCBvTYA+fRDNxAHc9TmYDP/eAaUlCBBsK5AUM5Ym"
    ];

    # Pangolin: the public reverse proxy + WireGuard tunnel server, running as
    # the upstream container stack - see nixosModules.pangolin-docker for the
    # containers, the generated config.yml and the traefik configuration.
    #
    # DNS lives in Cloudflare and MUST be "DNS only" (grey cloud):
    #   *.dazza9905.me  A  37.120.189.13
    # Proxying (orange cloud) breaks two things at once: WireGuard UDP 51820
    # does not survive Cloudflare's proxy, so newt can never dial in, and
    # Let's Encrypt's HTTP-01 challenge never reaches traefik.
    #
    # That wildcard *record* is what keeps this file small, and it is doing more
    # work than it looks. Because every subdomain resolves to this box, traefik
    # can answer an HTTP-01 challenge for any of them - including the hostnames
    # of private *site* resources (immich.*) that it does not actually serve.
    # So traefik ends up holding an ordinary per-hostname cert for those too,
    # pangolin's acmeCertSync imports it from acme.json, and pushes it down to
    # the newt client that really terminates the TLS. No wildcard *certificate*
    # is needed anywhere, so no DNS-01 and no Cloudflare API token.
    #
    # The dashboard is behind a login and disable_signup_without_invite is set,
    # so nobody can self-register.
    #
    # No allowUnfreePredicate any more: the licence gating lives in the image,
    # not in a nixpkgs `edition` argument, so nothing here is unfree.

    boot.loader.grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
    };

    environment.systemPackages = map lib.lowPrio [
      pkgs.curl
      pkgs.gitMinimal
      pkgs.neovim
    ];

    nix.settings.experimental-features = ["nix-command" "flakes"];

    system.stateVersion = "24.05";
  };
}
