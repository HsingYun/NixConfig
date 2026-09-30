{ config, lib, ... }:

{
  dconf.settings = {
    "org/gnome/settings-daemon/peripherals/touchscreen".orientation-lock =
      lib.mkIf config.features.desktop.gnome.enable (lib.mkDefault false);

    # Align sensor directions with the Pocket 4's landscape display orientation.
    "org/gnome/shell/extensions/screen-rotate".orientation-offset =
      lib.mkIf config.features.desktop.screenRotate.enable (lib.mkDefault 1);
  };

  home.stateVersion = "26.05";
}
