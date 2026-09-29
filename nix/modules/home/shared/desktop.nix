{ lib, software, ... }:

{
  imports = [
    ./launcher.nix
    ../software
  ];
  software.requirements.tela.capabilities = [ "store-package" ];

  desktop.launcher.hiddenEntries = lib.mkDefault [
    "htop.desktop"
    "vim.desktop"
    "gvim.desktop"
  ];

  gtk = {
    enable = lib.mkDefault true;
    iconTheme = {
      package = lib.mkDefault software.tela.package;
      name = lib.mkDefault "Tela";
    };
  };
}
