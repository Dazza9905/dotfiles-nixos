{
  self,
  inputs,
  ...
}: let
  hosts = import ./_hosts.nix;
  specialArgs = {
    inherit inputs;
    username = "dazza";
  };
in {
  # escape hatch: plain `nixos-rebuild switch --flake .` still works
  flake.nixosConfigurations = builtins.mapAttrs (name: _:
    inputs.nixpkgs.lib.nixosSystem {
      inherit specialArgs;
      modules = [self.nixosModules."${name}Configuration"];
    })
  hosts;

  flake.colmenaHive = inputs.colmena.lib.makeHive ({
      meta = {
        nixpkgs = import inputs.nixpkgs {system = "x86_64-linux";};
        nodeNixpkgs =
          builtins.mapAttrs (_: host: import inputs.nixpkgs {inherit (host) system;}) hosts;
        inherit specialArgs;
      };
    }
    // builtins.mapAttrs (name: host: {
      imports = [self.nixosModules."${name}Configuration"];
      deployment = {
        inherit (host) targetHost targetUser tags;
        allowLocalDeployment = host.allowLocalDeployment or false;
      };
    })
    hosts);
}
