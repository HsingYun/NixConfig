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
    initContent = lib.mkOrder 1500 ''
      # Load private machine-local settings at shell startup, outside the Nix store.
      if [[ -r "$HOME/.config/zsh/local.zsh" ]]; then
        source "$HOME/.config/zsh/local.zsh"
      fi
    '';
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
