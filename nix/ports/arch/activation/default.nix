{ ... }:
{
  imports = [
    ./packages.nix
    ./chrome.nix
    ./smartcard.nix
    ./login-manager.nix
    ./niri.nix
  ];
  native.privilegeCommand = [ "/usr/bin/sudo" ];
}
