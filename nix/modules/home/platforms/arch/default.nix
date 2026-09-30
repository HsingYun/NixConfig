{ ... }:
{
  imports = [
    ./dconf.nix
    ./services.nix
    ./desktop-session.nix
    ./desktop-services.nix
    ./input-method-lifecycle.nix
    ./smartcard.nix
    ./login-manager.nix
    ./chrome.nix
  ];
  targets.genericLinux.enable = true;
}
