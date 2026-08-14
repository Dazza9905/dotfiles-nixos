{inputs, ...}: {
  flake.nixosModules.sops = {
    imports = [inputs.sops-nix.nixosModules.sops];

    # Host ssh key doubles as the age identity, so no extra key provisioning:
    # after first boot run `ssh-keyscan <host> | ssh-to-age` and add the result
    # to .sops.yaml, then `sops updatekeys secrets/<host>.yaml`.
    sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  };
}
