{ profile, ... }:
{
  platform = "nixos-wsl";
  packageManager = "nix";
  system = "x86_64-linux";
  stateVersion = {
    home = "26.05";
    system = "26.11";
  };
  profiles = profile.cli;
  features = {
    wsl.usbip.enable = true;
    gpg.pinentry = "curses";
    smartcard = {
      allowBackgroundAccess = true;
    };
  };
}
