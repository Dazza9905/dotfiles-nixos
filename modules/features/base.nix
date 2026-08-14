# server-safe baseline shared by every host; desktop stuff stays per-host
{self, ...}: {
  flake.nixosModules.base = {
    imports = [
      self.nixosModules.nix-settings
      self.nixosModules.time-lang
      self.nixosModules.ssh
      self.nixosModules.sudo
      self.nixosModules.deployment
    ];
  };
}
