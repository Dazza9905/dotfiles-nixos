{ self,
  inputs,
  ...
}: {
  flake.nixosModules."programs-3d" = {
    pkgs,
    username,
    ...
  }: {
    users.users.${username}.packages = with pkgs; [
      blender
      prusa-slicer
      plasticity
      (lycheeslicer.overrideAttrs (old: {
        postInstall =
          (old.postInstall or "")
          + ''
            substituteInPlace "$out/share/applications/Lychee Slicer.desktop" \
              --replace "MimeType=model/stl" "MimeType=model/stl;x-scheme-handler/lycheeslicer"
          '';
      }))
    ];
  };
}
