{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.sudo = {username, ...}: {
    security.sudo.extraRules = [
      {
        users = [username];
        commands = [
          {
            command = "/run/current-system/sw/bin/colmena";
            options = ["NOPASSWD"];
          }
          {
            # escape hatch
            command = "/run/current-system/sw/bin/nixos-rebuild";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];
  };
}
