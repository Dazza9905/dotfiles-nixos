# Single source of truth for all fleet metadata.
# KEEP the underscore prefix: it stops import-tree from loading this plain-data
# file as a flake-parts module (renaming it to hosts.nix breaks the whole flake
# with "The option `dazzapc' does not exist").
{
  dazzapc = {
    system = "x86_64-linux";
    targetHost = "192.168.100.24";
    targetUser = "dazza";
    tags = ["desktop" "x86"];
    allowLocalDeployment = true;
  };
  # flow-z13 = {
  #   system = "x86_64-linux";
  #   targetHost = "flow-z13.lan"; # TODO: real LAN IP/hostname
  #   targetUser = "root";
  #   tags = ["laptop" "x86"];
  #   allowLocalDeployment = true;
  # };
  rpi5 = {
    system = "aarch64-linux";
    targetHost = "192.168.100.21"; # confirm on the pi with `hostname -I`
    targetUser = "root";
    tags = ["server" "arm"];
    allowLocalDeployment = false;
  };
}
