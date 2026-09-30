{ ... }:
{
  imports = [
    ./profile.nix
    ./capabilities/dms.nix
    ./capabilities/input-method.nix
    ./launcher.nix
    ./smartcard-client.nix
    ./keyring.nix
    ./pipewire.nix
  ];
  targets.genericLinux.enable = true;
}
