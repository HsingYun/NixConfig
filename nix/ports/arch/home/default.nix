{ ... }:
{
  imports = [
    ./capabilities/niri.nix
    ./capabilities/dms.nix
    ./capabilities/noctalia.nix
    ./capabilities/input-method.nix
    ./launcher.nix
    ./smartcard-client.nix
    ./keyring.nix
    ./pipewire.nix
  ];
  targets.genericLinux.enable = true;
  native.systemd.user.vendorDirectory = "/usr/lib/systemd/user";
}
