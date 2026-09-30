{ ... }:
{
  imports = [
    ./dms.nix
    ./input-method.nix
    ./launcher.nix
    ./smartcard-client.nix
    ./keyring.nix
    ./desktop-session.nix
    ./input-method-lifecycle.nix
  ];
  targets.genericLinux.enable = true;
}
