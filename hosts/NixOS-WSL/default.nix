{ profile, ... }:
{
  platform = "nixos-wsl";
  packageManager = "nix";
  system = "x86_64-linux";
  stateVersion = {
    home = "26.05";
    system = "26.11";
  };
  features = profile.cli // {
    wsl.usbip.enable = true;
    gpg.pinentry = "curses";
    smartcard = profile.cli.smartcard // {
      allowBackgroundAccess = true;
    };
  };
}
