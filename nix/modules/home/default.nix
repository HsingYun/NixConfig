{ pkgs, ... }:

{
  home.packages = import ../../packages/user-cli.nix { inherit pkgs; };
  programs.home-manager.enable = true;
}
