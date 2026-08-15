{self, ...}: {
  flake.nixosModules.laurieConfiguration = {
    lib,
    pkgs,
    ...
  }: let
    # Where traefik keeps its ACME state, and the group-readable mirror of it
    # that pangolin is pointed at instead (see pangolin-acme-sync below).
    acmeJson = "/var/lib/pangolin/config/letsencrypt/acme.json";
    acmeJsonMirror = "/var/lib/pangolin/config/acme-sync/acme.json";

    # The enterprise edition reads its own settings from privateConfig.yml,
    # which the NixOS module does not manage (it only writes config.yml).
    # Values are schema-parsed, so anything omitted keeps its upstream default -
    # notably flags.enable_acme_cert_sync, which stays true.
    pangolinPrivateConfig = pkgs.writeText "pangolin-private-config.yml" ''
      acme:
        acme_json_path: ${acmeJsonMirror}
    '';
  in {
    imports = [self.nixosModules.laurieHardware];

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

    # Pangolin: the public reverse proxy + WireGuard tunnel server. It brings
    # its own traefik and Let's Encrypt, so there is nothing else to configure.
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
    # openFirewall opens 80/tcp + 443/tcp (traefik) and 51820/udp (gerbil's
    # WireGuard endpoint, which newt site connectors dial). See the extra
    # firewall hole below - that list is not quite complete. The dashboard is
    # behind a login and disable_signup_without_invite defaults to true, so
    # nobody can self-register.
    #
    # The enterprise edition ships under the Fossorial Commercial License (free
    # for personal use; activate with a free Personal License key from
    # pangolin.net), so nixpkgs marks it unfree. Allow exactly this one package
    # rather than setting allowUnfree for the whole host.
    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) ["pangolin"];

    services.pangolin = {
      enable = true;
      openFirewall = true;
      baseDomain = "dazza9905.me";
      letsEncryptEmail = "darendrahos@fastmail.com";

      # nodejs 24.19.0 added ObjectWrap cleanup hooks that make better-sqlite3
      # abort ("Assertion failed: (env) != nullptr" in
      # RemoveEnvironmentCleanupHook) whenever GC collects a Statement, e.g. on
      # every "create organization". nixpkgs still defaults buildNpmPackage to
      # 24.19.0, so build against node 22 LTS; drop this once it ships a fix.
      package = pkgs.fosrl-pangolin.override {
        edition = "enterprise";
        buildNpmPackage = pkgs.buildNpmPackage.override {nodejs = pkgs.nodejs_22;};
      };

      # SERVER_SECRET signs sessions. Plaintext on disk, never in git/nix store:
      #   ssh root@laurie 'echo "SERVER_SECRET=$(openssl rand -hex 32)" > /root/pangolin.env'
      # Must exist before activation or pangolin and gerbil both fail to start.
      environmentFile = "/root/pangolin.env";
    };
    services.gerbil.environmentFile = "/root/pangolin.env";

    # Pangolin *clients* (the mobile app / olm, as opposed to newt site
    # connectors) NAT hole-punch against gerbil on 21820/udp. gerbil listens on
    # it, but services.pangolin.openFirewall only opens 51820/udp, so without
    # this the app just retries forever and pangolin logs "Can the client reach
    # the server on UDP port 21820?". Relay mode is not a workaround: the server
    # still requires a recent hole punch before it answers olm/wg/register.
    networking.firewall.allowedUDPPorts = [21820];

    # The pangolin wrapper refreshes /var/lib/pangolin/.next from the nix store
    # with `rm -rf .next && cp -rd ...`, but the copy keeps store modes (dirs
    # 555), so the rm fails on every later start and the UI keeps serving the
    # previous build's assets. Make it writable first.
    # (preStart is types.lines, so this appends to the module's own script.)
    systemd.services.pangolin = {
      preStart = ''
        chmod -R u+w /var/lib/pangolin/.next 2>/dev/null || true
        install -Dm640 ${pangolinPrivateConfig} /var/lib/pangolin/config/privateConfig.yml
      '';
      # so the readable acme.json mirror exists before the first sync tick
      wants = ["pangolin-acme-sync.service"];
      after = ["pangolin-acme-sync.service"];
    };

    # traefik hard-refuses to start its ACME resolver unless acme.json is 0600
    # and traefik-owned ("permissions 640 are too open"), and it keeps the
    # letsencrypt dir 0700, so pangolin (pangolin:fossorial) can neither
    # traverse to nor read the original. Mirror it to a fossorial-readable copy
    # and point the EE acmeCertSync at that instead. The copy holds the same
    # private keys but only widens them to pangolin/gerbil/traefik, which
    # already share this host's trust domain.
    systemd.services.pangolin-acme-sync = {
      description = "Mirror traefik's acme.json where pangolin can read it";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "pangolin-acme-sync" ''
          test -s ${acmeJson} || exit 0
          install -D -g fossorial -m 0640 ${acmeJson} ${acmeJsonMirror}
        '';
      };
    };

    # re-mirror whenever traefik renews a certificate
    systemd.paths.pangolin-acme-sync = {
      description = "Watch traefik's acme.json for certificate renewals";
      wantedBy = ["multi-user.target"];
      pathConfig.PathModified = acmeJson;
    };

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
