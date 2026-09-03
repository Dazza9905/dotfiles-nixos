{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.sops = {
      pkgs,
      username,
      ...
    }: {
    imports = [
      inputs.sops-nix.nixosModules.sops
    ];

    sops.defaultSopsFormat = "yaml";

    sops.age.keyFile = "/home/${username}/.config/sops/age/keys.txt";

    environment.systemPackages = with pkgs; [
      age
      sops
    ];



  };
}
