{ pkgs, ... }:

{
  software.packageOverrides.pinentry = pkgs.pinentry-curses;
  home.stateVersion = "26.05";
}
