{ lib, pkgs, ... }:

{
  home.packages = [ pkgs.git ];
  programs.zsh = {
    enable = lib.mkDefault true;
    oh-my-zsh = {
      enable = lib.mkDefault true;
      theme = lib.mkDefault "ys";
      plugins = lib.mkDefault [
        "git"
        "sudo"
      ];
    };
  };
}
