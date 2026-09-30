{ lib, ... }:

{
  software = {
    requirements = {
      git = { };
      zsh.capabilities = [ "store-package" ];
    };
  };
  programs.zsh = {
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
