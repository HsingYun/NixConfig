{
  config,
  lib,
  ...
}:
let
  cfg = config;
in
{
  imports = [
    ../../../../contracts/system/services/gnome.nix
    ../../../../contracts/system/services/niri.nix
    ../../../../contracts/system/services/dms.nix
    ../../../../contracts/system/services/session.nix
  ];
  config = lib.mkMerge [
    (lib.mkIf cfg.services.desktopManager.gnome.enable {
      native.requiredPackages = [
        "gdm"
        "gnome-color-manager"
        "gnome-control-center"
        "gnome-disk-utility"
        "gnome-font-viewer"
        "gnome-keyring"
        "gnome-logs"
        "gnome-menus"
        "gnome-session"
        "gnome-settings-daemon"
        "gnome-shell"
        "gnome-system-monitor"
        "loupe"
        "malcontent"
        "papers"
        "sushi"
        "seahorse"
        "xdg-desktop-portal-gnome"
      ];
      services.avahi.enable = lib.mkDefault true;
    })
    (lib.mkIf cfg.programs.niri.enable {
      native.requiredPackages = [
        "niri"
        "xwayland-satellite"
        "xdg-desktop-portal-gnome"
        "xdg-desktop-portal-gtk"
      ];
    })
    (lib.mkIf cfg.programs.dms-shell.enable { native.requiredPackages = [ "dms" ]; })
    {
      services.greetd.enable = lib.mkIf cfg.services.displayManager.dms-greeter.enable (
        lib.mkDefault true
      );
      assertions = [
        {
          assertion = !cfg.services.displayManager.dms-greeter.enable || cfg.services.greetd.enable;
          message = "DMS greeter requires greetd.";
        }
        {
          assertion = !cfg.services.displayManager.dms-greeter.enable || cfg.programs.niri.enable;
          message = "The Arch DMS greeter requires its Niri compositor to be enabled through programs.niri.enable.";
        }
        {
          assertion = !cfg.programs.dms-shell.enable || cfg.programs.niri.enable;
          message = "The Arch DMS session port requires Niri.";
        }
      ];
    }
  ];
}
