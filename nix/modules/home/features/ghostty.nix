{ lib, pkgs, ... }:

{
  programs.ghostty = {
    enable = lib.mkDefault true;
    enableZshIntegration = lib.mkDefault true;
    settings = lib.mapAttrs (_: lib.mkDefault) {
      font-family = "JetBrainsMono Nerd Font";
      font-size = 12;
      theme = "Catppuccin Mocha";
      window-decoration = false;
      window-padding-x = 12;
      window-padding-y = 10;
      confirm-close-surface = true;
    };
  };

  fonts.fontconfig.enable = lib.mkDefault true;
  home.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
  home.sessionVariables.TERMINAL = lib.mkDefault "ghostty";
  xdg.terminal-exec = {
    enable = lib.mkDefault true;
    settings.default = lib.mkDefault [ "com.mitchellh.ghostty.desktop" ];
  };
}
