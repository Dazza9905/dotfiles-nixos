{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.gamedev = {
    pkgs,
    username,
    ...
  }: {
    users.users.${username}.packages = with pkgs; [
      godot
    ];
  };
}
