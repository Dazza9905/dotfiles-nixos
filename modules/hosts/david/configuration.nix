{
  self,
  lib,
  pkgs,
  ...
}: {
  flake.nixosModules.davidConfiguration = {
    lib,
    ...
  }: {
    imports = [
      self.nixosModules.davidHardware
    ];

















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

    networking.hostName = "david";

    services.openssh.enable = true;
    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINt6vCBvTYA+fRDNxAHc9TmYDP/eAaUlCBBsK5AUM5Ym"
    ];
    # ++ (args.extraPublicKeys or [ ]); # used for unit-testing this module

    system.stateVersion = "26.05";
  };
}
