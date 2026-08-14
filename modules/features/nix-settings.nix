{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.nix-settings = {
    pkgs,
    lib,
    username,
    ...
  }: {
    nix.settings.auto-optimise-store = true;
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    nix.settings.trusted-users = ["root" "${username}"];
    nixpkgs.config.allowUnfree = true;

    nixpkgs.overlays = [
      (final: prev: {
        # ffmpeg 9.0 removed the AVVulkanDeviceContext fields moonlight-qt
        # 6.1.0's Vulkan renderer still uses; pin to ffmpeg_7 until either
        # side updates. https://github.com/moonlight-stream/moonlight-qt
        moonlight-qt = prev.moonlight-qt.override {ffmpeg = prev.ffmpeg_7;};
      })
    ];

    programs.nix-ld.enable = true;

    nix.settings.experimental-features = ["nix-command" "flakes"];
  };
}
