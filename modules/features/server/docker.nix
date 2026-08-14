{
  flake.nixosModules.docker = {
    pkgs,
    username,
    ...
  }: {
    # Remaining compose stacks stay imperative in /opt/stacks (still mirrored
    # to B2 by the data-backup job).
    virtualisation.docker.enable = true;
    users.users.${username}.extraGroups = ["docker"];
    environment.systemPackages = [pkgs.docker-compose];
  };
}
