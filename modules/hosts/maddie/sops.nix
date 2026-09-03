{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.maddieSops = {

    imports = [
      inputs.sops-nix.nixosModules.sops
    ];

    sops.defaultSopsFile = ../../../secrets/maddie.yaml;



  };
}
