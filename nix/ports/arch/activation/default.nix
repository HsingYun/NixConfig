{ ... }:
{
  imports = [
    ./systemd.nix
    ../../../modules/software/backends/pacman.nix
    ./chrome.nix
    ./smartcard.nix
    ./login-manager.nix
    ./profile.nix
  ];
}
