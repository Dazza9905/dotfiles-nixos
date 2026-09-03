{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.maddieConfiguration = {
    lib,
    pkgs,
    config,
    ...
  }: {
    imports = [
      inputs.nixos-hardware.nixosModules.raspberry-pi-5
      self.nixosModules.maddieHardware
      self.nixosModules.maddieSops
      self.nixosModules.time-lang
      self.nixosModules.homelab
    ];

    nix.settings.auto-optimise-store = true;
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    homelab = { enable = true;
      mount = "/mnt/860evo";

      services = {

        immich = {
          enable = true;
          mediaDir = "/mnt/860evo/immich-app/data";
          ipp = true;
        };

        newt = {
          enable = true;
        };
      };
    };
    
    # services.immich-public-proxy = {
    #   enable = true;
    # };

    fileSystems."/mnt/860evo"= {
      device = "/dev/disk/by-uuid/449c6c1f-0f80-4e17-b5e2-00c40a6e8151";
      fsType = "ext4";
      options = ["rw" "nofail"];
    };

    environment.systemPackages = with pkgs; [
      htop
      systemctl-tui
    ];


    networking.firewall.enable = true;
    networking.firewall.allowedTCPPorts = [
      22 2283
    ];
    nix.settings.experimental-features = ["nix-command" "flakes"];
    # ------------------------------------------------------------------
    # RPI5 STUFF
    # ------------------------------------------------------------------
    boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

    hardware.raspberry-pi.firmware = {
      enable = true;
      uboot.enable = true;
    };

    #ethernet
    boot.loader.generic-extlinux-compatible.useGenerationDeviceTree = true;

    hardware.raspberry-pi.configtxt.settings.all.avoid_warnings = 1;

    networking.hostName = "maddie";

    services.openssh.enable = true;
    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINt6vCBvTYA+fRDNxAHc9TmYDP/eAaUlCBBsK5AUM5Ym"
    ];

    system.stateVersion = "26.05";
  };
}
