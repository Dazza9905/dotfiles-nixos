# Pangolin the way upstream ships it: three containers, declared in Nix.
#
# This replaces services.pangolin from nixpkgs. That module unpacks pangolin
# into the nix store and runs it as a hardened systemd service, which is where
# every one of the workarounds this host used to carry came from - the .next
# chmod against store modes, the acme.json permission mirror, hand-installing
# privateConfig.yml, and the nodejs_22 pin for the better-sqlite3 abort. None
# of them exist here, because the image brings its own runtime and writes to an
# ordinary bind mount.
#
# This mirrors https://docs.pangolin.net/self-host/manual/docker-compose - the
# installer's own layout, hand-maintained. Note that page and the repo's
# compose.example.yaml disagree (traefik v3.6 vs v3.7, badger v1.4.0 vs v1.4.1,
# a ws-router the repo file lacks); the docs page wins here. Diff against it
# when upstream changes.
#
# Deliberate departures from that page, all flagged again at their use site:
#   - server.secret is supplied as SERVER_SECRET from an env file rather than
#     written into config.yml, so it never enters the nix store
#   - an accessLog block, which the docs provision a logs directory for but
#     never actually enable
#   - telemetry.anonymous_usage is off
#   - pull = "always", so the `latest` tags the docs use really do float
#   - traefik is ordered after gerbil, which compose gets for free
#
# WHAT IS DIFFERENT FROM A NORMAL NIXOS SERVICE, and is easy to forget:
# docker publishes ports by DNAT in nat/PREROUTING, so traffic to 80, 443,
# 51820 and 21820 never traverses INPUT and networking.firewall does not
# describe what is reachable on this box any more. Deliberately nothing is
# added to allowedTCPPorts below - it would be decoration. The one real
# consequence is for crowdsec: a firewall bouncer left on its default
# iptables_chains = ["INPUT"] silently blocks nothing here, and needs
# "DOCKER-USER" adding.
{
  flake.nixosModules.pangolin-docker = {pkgs, ...}: let
    baseDomain = "dazza9905.me";
    dashboardDomain = "pangolin.${baseDomain}";
    letsEncryptEmail = "darendrahos@fastmail.com";

    # Upstream bind-mounts a relative ./config. The nixpkgs module happened to
    # use the same internal layout under /var/lib/pangolin - config.yml, key,
    # letsencrypt/acme.json, traefik/ - so pointing the containers here carries
    # the existing sqlite db, certificates, sites and resources straight over
    # rather than starting from an empty dashboard.
    stateDir = "/var/lib/pangolin";
    configDir = "${stateDir}/config";

    yaml = pkgs.formats.yaml {};

    # config.yml. Upstream templates this from config.example.yml at install
    # time; generating it here is the actual "docker config inside nix" win,
    # since it is otherwise a file you hand-edit on the server and forget.
    #
    # DEPARTURE from the docs: they write server.secret straight into this
    # file. Everything Nix generates is world-readable in /nix/store, so the
    # secret is passed as SERVER_SECRET from an env file instead and this file
    # omits it. That is the same mechanism the nixpkgs module used, so it is
    # known to work against this application - but it is the one thing here
    # that is not doing what the page says, and a wrong guess would show up as
    # pangolin refusing to start rather than as anything subtle.
    pangolinConfig = yaml.generate "config.yml" {
      gerbil = {
        start_port = 51820;
        base_endpoint = dashboardDomain;
      };
      app = {
        dashboard_url = "https://${dashboardDomain}";
        log_level = "info";
        telemetry.anonymous_usage = false;
      };
      domains.domain1.base_domain = baseDomain;
      server.cors = {
        origins = ["https://${dashboardDomain}"];
        methods = ["GET" "POST" "PUT" "DELETE" "PATCH"];
        allowed_headers = ["X-CSRF-Token" "Content-Type"];
        credentials = false;
      };
      flags = {
        require_email_verification = false;
        disable_signup_without_invite = true;
        disable_user_create_org = false;
        allow_raw_resources = true;
      };
    };

    # Traefik's static config. Note the service names: inside the compose
    # network the containers address each other by container name, so this is
    # http://pangolin:3001 rather than the localhost the nixpkgs module used.
    traefikStatic = yaml.generate "traefik_config.yml" {
      api = {
        # upstream default. This listens on :8080 inside gerbil's network
        # namespace, and gerbil publishes only 80/443/51820/21820, so it is
        # not reachable from outside the host.
        insecure = true;
        dashboard = true;
      };
      providers = {
        http = {
          endpoint = "http://pangolin:3001/api/v1/traefik-config";
          pollInterval = "5s";
        };
        file.filename = "/etc/traefik/dynamic_config.yml";
      };
      # docs pin v1.4.0; the repo's own config/traefik/traefik_config.yml says
      # v1.4.1. Following the docs - check github.com/fosrl/badger before bumping.
      experimental.plugins.badger = {
        moduleName = "github.com/fosrl/badger";
        version = "v1.4.0";
      };
      log = {
        level = "INFO";
        format = "common";
        maxSize = 100;
        maxBackups = 3;
        maxAge = 3;
        compress = true;
      };
      # DEPARTURE from the docs. They mount config/traefik/logs into the
      # container at /var/log/traefik but never define accessLog, so nothing is
      # ever written there. Traefik keeps no access log by default and crowdsec
      # has nothing to read without one, so this fills in the missing half.
      accessLog = {
        filePath = "/var/log/traefik/access.log";
        format = "json";
      };
      certificatesResolvers.letsencrypt.acme = {
        httpChallenge.entryPoint = "web";
        email = letsEncryptEmail;
        storage = "/letsencrypt/acme.json";
        caServer = "https://acme-v02.api.letsencrypt.org/directory";
      };
      entryPoints = {
        web.address = ":80";
        websecure = {
          address = ":443";
          transport.respondingTimeouts.readTimeout = "30m";
          http = {
            tls.certResolver = "letsencrypt";
            encodedCharacters = {
              allowEncodedSlash = true;
              allowEncodedQuestionMark = true;
            };
          };
        };
      };
      serversTransport.insecureSkipVerify = true;
      ping.entryPoint = "web";
    };

    # Only the dashboard's own routers live here. Every *resource* router is
    # served by the http provider above, straight out of pangolin's database,
    # which is why this file stays short and why resources remain dashboard
    # click-ops rather than something declarable in Nix.
    traefikDynamic = yaml.generate "dynamic_config.yml" {
      http = {
        middlewares = {
          badger.plugin.badger.disableForwardAuth = true;
          redirect-to-https.redirectScheme.scheme = "https";
        };
        routers = {
          main-app-router-redirect = {
            rule = "Host(`${dashboardDomain}`)";
            service = "next-service";
            entryPoints = ["web"];
            middlewares = ["redirect-to-https" "badger"];
          };
          next-router = {
            rule = "Host(`${dashboardDomain}`) && !PathPrefix(`/api/v1`)";
            service = "next-service";
            entryPoints = ["websecure"];
            middlewares = ["badger"];
            tls.certResolver = "letsencrypt";
          };
          api-router = {
            rule = "Host(`${dashboardDomain}`) && PathPrefix(`/api/v1`)";
            service = "api-service";
            entryPoints = ["websecure"];
            middlewares = ["badger"];
            tls.certResolver = "letsencrypt";
          };
          # Present in the docs, absent from the repo's compose.example.yaml.
          # Its rule is the shortest of the three on websecure, so traefik's
          # default longest-rule-wins priority makes it the fallback that
          # catches websocket upgrades and sends them to the API rather than
          # to next.
          ws-router = {
            rule = "Host(`${dashboardDomain}`)";
            service = "api-service";
            entryPoints = ["websecure"];
            middlewares = ["badger"];
            tls.certResolver = "letsencrypt";
          };
        };
        services = {
          next-service.loadBalancer.servers = [{url = "http://pangolin:3002";}];
          api-service.loadBalancer.servers = [{url = "http://pangolin:3000";}];
        };
      };
      tcp.serversTransports = {
        pp-transport-v1.proxyProtocol.version = 1;
        pp-transport-v2.proxyProtocol.version = 2;
      };
    };

    # compose's `depends_on: condition: service_healthy`. oci-containers'
    # dependsOn only gives systemd ordering, which starts gerbil the instant
    # the pangolin *container* exists - not when the app inside it is serving.
    waitForPangolin = pkgs.writeShellScript "wait-for-pangolin" ''
      for _ in $(seq 1 60); do
        case "$(${pkgs.docker}/bin/docker inspect -f '{{.State.Health.Status}}' pangolin 2>/dev/null)" in
          healthy) exit 0 ;;
        esac
        sleep 2
      done
      echo "pangolin did not become healthy within 120s" >&2
      exit 1
    '';
  in {
    virtualisation.docker.enable = true;
    virtualisation.oci-containers.backend = "docker";

    virtualisation.oci-containers.containers = {
      pangolin = {
        image = "docker.io/fosrl/pangolin:latest";
        # `latest` only means latest if it is re-resolved; the module's default
        # policy is "missing", which would pin you to whatever was pulled the
        # first time and never move again. The cost is that a restart now
        # needs the network and can change versions under you.
        pull = "always";
        volumes = ["${configDir}:/app/config"];
        networks = ["pangolin"];
        # SERVER_SECRET signs sessions. Same file the native setup used:
        #   ssh root@laurie 'echo "SERVER_SECRET=$(openssl rand -hex 32)" > /root/pangolin.env'
        environmentFiles = ["/root/pangolin.env"];
        # upstream's healthcheck, which is what waitForPangolin polls
        extraOptions = [
          "--health-cmd=curl -f http://localhost:3001/api/v1/ || exit 1"
          "--health-interval=10s"
          "--health-timeout=10s"
          "--health-retries=15"
        ];
      };

      gerbil = {
        image = "docker.io/fosrl/gerbil:latest";
        pull = "always";
        dependsOn = ["pangolin"];
        networks = ["pangolin"];
        volumes = ["${configDir}:/var/config"];
        cmd = [
          "--reachableAt=http://gerbil:3004"
          "--generateAndSaveKeyTo=/var/config/key"
          "--remoteConfig=http://pangolin:3001/api/v1/"
        ];
        capabilities = {
          NET_ADMIN = true;
          SYS_MODULE = true;
        };
        # 80 and 443 are published here, not on traefik: traefik shares this
        # container's network namespace, so it has no ports of its own.
        # 21820/udp is the one the mobile app hole-punches against - it was a
        # separate firewall hole on the native setup and is upstream default here.
        ports = [
          "51820:51820/udp"
          "21820:21820/udp"
          "443:443"
          "80:80"
        ];
      };

      traefik = {
        image = "docker.io/traefik:v3.6";
        pull = "always";
        # The docs order traefik after pangolin-healthy. Under compose the
        # gerbil dependency is implicit in network_mode; here it has to be
        # said, and it is the stronger constraint anyway - gerbil already
        # waits for pangolin to be healthy, so this inherits that.
        dependsOn = ["gerbil"];
        cmd = ["--configFile=/etc/traefik/traefik_config.yml"];
        volumes = [
          "${configDir}/traefik:/etc/traefik:ro"
          "${configDir}/letsencrypt:/letsencrypt"
          # a writable mount nested inside the read-only one above, which is
          # exactly how the docs do it
          "${configDir}/traefik/logs:/var/log/traefik"
        ];
        # compose's `network_mode: service:gerbil`. Mutually exclusive with
        # `networks` - traefik has no network identity of its own, which is why
        # the dynamic config reaches pangolin by name through gerbil's stack.
        extraOptions = ["--network=container:gerbil"];
      };
    };

    # oci-containers attaches containers to networks but never creates them,
    # so without this every unit fails with "network pangolin not found".
    # The docs ship `enable_ipv6` commented out, so no --ipv6 here; add it if
    # you ever want v6 inside the stack.
    systemd.services.docker-network-pangolin = {
      description = "Create the pangolin docker network";
      after = ["docker.service"];
      requires = ["docker.service"];
      wantedBy = ["multi-user.target"];
      path = [pkgs.docker];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        docker network inspect pangolin >/dev/null 2>&1 && exit 0
        docker network create pangolin
      '';
    };

    # The generated files are copied rather than bind-mounted from the store:
    # pangolin rewrites config.yml in place, and a read-only store path would
    # make that fail. Copying on every start keeps Nix as the source of truth
    # while leaving the file writable at runtime.
    systemd.services.pangolin-config = {
      description = "Install pangolin and traefik configuration";
      wantedBy = ["multi-user.target"];
      before = ["docker-pangolin.service" "docker-traefik.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        install -Dm640 ${pangolinConfig} ${configDir}/config.yml
        install -Dm644 ${traefikStatic} ${configDir}/traefik/traefik_config.yml
        install -Dm644 ${traefikDynamic} ${configDir}/traefik/dynamic_config.yml
        # the docs' `mkdir -p config/db config/letsencrypt config/traefik/logs`
        install -d -m750 ${configDir}/db ${configDir}/letsencrypt ${configDir}/traefik/logs
      '';
    };

    systemd.services.docker-pangolin = {
      after = ["pangolin-config.service" "docker-network-pangolin.service"];
      requires = ["pangolin-config.service" "docker-network-pangolin.service"];
    };

    systemd.services.docker-gerbil = {
      after = ["docker-network-pangolin.service"];
      requires = ["docker-network-pangolin.service"];
      serviceConfig.ExecStartPre = [waitForPangolin];
    };

    systemd.services.docker-traefik.after = ["pangolin-config.service"];
  };
}
