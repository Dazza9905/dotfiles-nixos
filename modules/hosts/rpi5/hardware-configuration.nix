{...}: {
  flake.nixosModules.rpi5Hardware = {lib, ...}: {
    # PLACEHOLDER — replace with the generated hardware-configuration.nix
    # (nixos-generate-config) after installing NixOS on the Pi 5.
    fileSystems."/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };

    nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  };
}
