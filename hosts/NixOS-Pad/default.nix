{ profile, ... }:
{
  platform = "nixos";
  packageManager = "nix";
  system = "x86_64-linux";
  features = profile.linuxDesktop // {
    efiTools.enable = true;
    desktop = profile.linuxDesktop.desktop // {
      gnome = {
        enable = true;
        settings."org/gnome/desktop/a11y/applications".screen-keyboard-enabled = false;
      };
      niri.enable = false;
      dms.enable = false;
      screenRotate.enable = true;
    };
  };
  hardwareConfig = ./hardware.nix;
  systemConfig = ./system.nix;
  homeConfig = ./home.nix;
}
