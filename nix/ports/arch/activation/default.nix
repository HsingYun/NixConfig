{ ... }:
{
  imports = [
    ./systemd.nix
    ./packages.nix
    ./chrome.nix
    ./smartcard.nix
    ./login-manager.nix
    ./profile.nix
  ];
}
