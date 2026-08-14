{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.programs-basic = {
    pkgs,
    lib,
    self',
    username,
    ...
  }: {
    imports = [
      self.nixosModules.zen
      self.nixosModules.yazi
      self.nixosModules.ncspot
      self.nixosModules.btop
    ];

    programs.localsend = {
      enable = true;
    };

    users.users.${username} = {
      packages = with pkgs; [
        self.packages.${pkgs.stdenv.hostPlatform.system}.myHelix
        github-cli
        kitty
        anki
        vesktop
        playerctl
        claude-code
        anki
        playerctl
        beeper
        gparted
        claude-code
        moonlight-qt
      ];
    };
    environment.systemPackages = with pkgs; [
      pciutils
      lazygit
      neovim
      git
      stow
      fd
      fzf
      eza
      zip
      unzip
      bat
      nwg-displays
      pavucontrol
      ntfs3g
      dust
      zellij
      ripgrep
      bob-nvim
      zoxide
      starship
      libnotify
      brightnessctl
      devenv
      t3code
      bitwarden-desktop
    ];
  };
}
