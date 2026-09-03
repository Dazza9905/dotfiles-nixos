{
  # MAIN PC
  caspian = {
    system = "x86_64-linux";
    targetHost = "192.168.100.24";
    targetUser = "dazza";
    tags = ["desktop" "x86"];
    allowLocalDeployment = true;
  };

  # NOTEBOOK
  # laurie = { 
  #   system = "x86_64-linux";
  #   targetHost = "flow-z13.lan";
  #   targetUser = "root";
  #   tags = ["laptop" "x86"];
  #   allowLocalDeployment = true;
  # };

  # HOMELAB SERVER
  maddie = {
    system = "aarch64-linux";
    targetHost = "192.168.100.21";
    targetUser = "root";
    tags = ["server" "arm"];
    allowLocalDeployment = false;
  };

  # PUBLIC PROXY - DEBIAN
  safesurf = { 
    system = "x86_64-linux";
    targetHost = "37.120.189.13";
    targetUser = "root";
    tags = ["server" "vps"];
    allowLocalDeployment = false;
  };

  # GAMESERVER
  # david = {
  #   ...
  # };
}
