{
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../../../modules/system/shared/desktop.nix
    ./network.nix
  ];

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];
}
