{ pkgs, ... }:

{
  home.packages = with pkgs; [
    google-chrome
    vscode
    codex
  ];

  home.stateVersion = "26.05";
}
