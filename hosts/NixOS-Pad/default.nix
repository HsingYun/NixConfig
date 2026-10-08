{ profile, ... }:
{
  platform = "nixos";
  packageManager = "nix";
  system = "x86_64-linux";
  stateVersion = {
    home = "26.05";
    system = "26.11";
  };
  timeZone = "Asia/Shanghai";
  features = profile.linuxDesktop // {
    efiTools.enable = true;
    desktop = profile.linuxDesktop.desktop // {
      autostart = {
        enable = true;
        entries.terminal.application = "terminal";
      };
      gnome = {
        enable = true;
        settings."org/gnome/desktop/a11y/applications".screen-keyboard-enabled = false;
        settings."org/gnome/settings-daemon/peripherals/touchscreen".orientation-lock = false;
      };
      niri.enable = false;
      dms.enable = false;
      screenRotate = {
        enable = true;
        # Align the sensor with the Pocket 4's landscape display.
        settings.orientation-offset = 1;
      };
    };
  };
  hardwareConfig = ./hardware.nix;
}
