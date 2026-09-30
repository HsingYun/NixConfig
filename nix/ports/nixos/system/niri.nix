{
  pkgs,
  ...
}:

{
  imports = [
    ../../../modules/system/features/niri.nix
    ./desktop.nix
  ];
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
}
