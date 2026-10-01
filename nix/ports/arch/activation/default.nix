{ ... }:
{
  imports = [
    ./packages.nix
    ./chrome.nix
    ./smartcard.nix
    ./login-manager.nix
  ];
  native.privilegeCommand = [ "/usr/bin/sudo" ];
}
