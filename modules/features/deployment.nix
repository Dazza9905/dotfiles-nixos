{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.deployment = {
    pkgs,
    lib,
    ...
  }: let
    system = pkgs.stdenv.hostPlatform.system;
  in {
    environment.systemPackages = [
      inputs.colmena.packages.${system}.colmena
      self.packages.${system}.rebuild
      self.packages.${system}.deploy
    ];

    # colmena deploys as root over SSH; key-only — password login for root stays impossible
    services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";
    services.openssh.settings.AllowUsers = ["root"];
    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICoX8q4oyO5E5lMUYnrFzFgSvSbHeZ8G7WkM42wBFYe2"
    ];
  };

  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    packages.rebuild = pkgs.writeShellApplication {
      name = "rebuild";
      excludeShellChecks = ["SC2024"];
      text = ''
        alejandra="${lib.getExe pkgs.alejandra}"
        notify_send="${lib.getExe' pkgs.libnotify "notify-send"}"
        git="${lib.getExe pkgs.git}"
        CONFIG_DIR="$HOME/.nixconf/"
        LOG="/tmp/nixos-switch.log"
        DOTFILES_DIR="$HOME/.dotfiles/"


        pushd "$CONFIG_DIR" >/dev/null
        echo "Formatting nix files..."
        "$alejandra" . &>/dev/null || {
            "$alejandra" .
            echo "formatting failed!"
            "$notify_send" -u critical -e "NixOS Rebuild" "Formatting failed"
            popd >/dev/null
            exit 1
        }
        current="."
        echo "Changes:"
        "$git" diff
        echo "NixOS rebuilding (colmena apply-local)..."
        # `sudo colmena`, NOT `colmena apply-local --sudo`: --sudo re-execs the
        # resolved /nix/store path, which the scoped NOPASSWD rule for
        # /run/current-system/sw/bin/colmena cannot match.
        if sudo colmena apply-local &>"$LOG"; then
            gen=$(readlink /nix/var/nix/profiles/system | grep -oE '[0-9]+')
            current="gen $gen ($(date '+%Y-%m-%d %H:%M:%S'))"
            echo "Current generation: $current"
            "$git" commit -am "$current"
            "$notify_send" -e "NixOS Rebuilt OK!" --icon=software-update-available
        else
            echo "Rebuild failed, errors below:"
            grep --color=always -i error "$LOG" || cat "$LOG"
            ERR_SUMMARY=$(grep -i error "$LOG" | head -n 3)
            "$notify_send" -u critical -e "NixOS Rebuild Failed" "''${ERR_SUMMARY:-Check $LOG for details}"
            popd >/dev/null
            exit 1
        fi
        cd "$DOTFILES_DIR"
        "$git" add .
        "$git" commit -am "$current"
        popd >/dev/null
      '';
    };

    packages.deploy = pkgs.writeShellApplication {
      name = "deploy";
      text = ''
        cd "$HOME/.nixconf"
        target="''${1:?usage: deploy <node|@tag> [extra colmena args...]}"
        shift
        exec colmena apply --on "$target" "$@"
      '';
    };
  };
}
