{ ... }:
{
  imports = [
    ../../common/home/capabilities/ghostty.nix
    ../../common/home/capabilities/mpv.nix
    ../../common/home/capabilities/vim.nix
    ./capabilities/niri.nix
    ./capabilities/dms.nix
    ./capabilities/noctalia.nix
    ./capabilities/input-method.nix
    ./capabilities/launcher.nix
    ./integrations/gpg-smartcard.nix
    ./capabilities/gnome-keyring.nix
    ./integrations/pipewire.nix
  ];
  targets.genericLinux.enable = true;
  native.systemd.user.vendorDirectory = "/usr/lib/systemd/user";
}
