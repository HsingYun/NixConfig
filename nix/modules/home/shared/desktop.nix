{ lib, pkgs, ... }:

{
  imports = [ ./launcher.nix ];

  desktop.launcher.hiddenEntries = lib.mkDefault [
    "htop.desktop"
    "vim.desktop"
    "gvim.desktop"
  ];

  gtk = {
    enable = lib.mkDefault true;
    iconTheme = {
      package = lib.mkDefault pkgs.tela-icon-theme;
      name = lib.mkDefault "Tela";
    };
  };
}
