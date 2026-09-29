{ lib, software, ... }:

{
  software.bindings.zsh = {
    enableOption = [
      "programs"
      "zsh"
      "enable"
    ];
    packageOption = [
      "programs"
      "zsh"
      "package"
    ];
  };
  software.requirements = {
    git = { };
    zsh.capabilities = [ "store-package" ];
  };
  programs.zsh = {
    package = lib.mkDefault software.zsh.package;

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
