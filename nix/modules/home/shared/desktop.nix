{ lib, pkgs, ... }:

{
  gtk = {
    enable = lib.mkDefault true;
    iconTheme = {
      package = lib.mkDefault pkgs.tela-icon-theme;
      name = lib.mkDefault "Tela";
    };
  };
}
