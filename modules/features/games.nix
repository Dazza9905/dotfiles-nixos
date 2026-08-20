{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.games = {
    pkgs,
    lib,
    username,
    ...
  }: {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
    };
    programs.gamemode.enable = true;


    environment.systemPackages = with pkgs; [
      prismlauncher
    ];
  };
}
