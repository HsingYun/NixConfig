{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config;
  native = packages: units: {
    native.requiredPackages = packages;
    native.systemd.units = units;
  };
in
{
  imports = [ ../../../contracts/system/desktop.nix ];
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
    (lib.mkIf cfg.networking.networkmanager.enable (
      lib.mkMerge [
        (native [ "networkmanager" ] [ "NetworkManager.service" ])
        {
          native.systemd.enableOnly = [ "NetworkManager-wait-online.service" ];
          native.activation.checkNativeDesktopNetwork = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
            ${pkgs.python3}/bin/python ${../../../assets/helpers/arch/network-preflight.py}
          '';
        }
      ]
    ))
    (lib.mkIf cfg.hardware.bluetooth.enable (native [ "bluez" "bluez-utils" ] [ "bluetooth.service" ]))
    (lib.mkIf cfg.security.rtkit.enable (native [ "rtkit" ] [ ]))
    (lib.mkIf cfg.services.pipewire.enable {
      native.requiredPackages = [
        "pipewire"
        "wireplumber"
      ]
      ++ lib.optional cfg.services.pipewire.alsa.enable "pipewire-alsa"
      ++ lib.optional cfg.services.pipewire.pulse.enable "pipewire-pulse";
    })
    (lib.mkIf cfg.services.upower.enable (native [ "upower" ] [ ]))
    (lib.mkIf cfg.services.udisks2.enable (native [ "udisks2" ] [ ]))
    (lib.mkIf cfg.services.gvfs.enable (native [ "gvfs" ] [ ]))
    {
      services.greetd.enable = lib.mkIf cfg.services.displayManager.dms-greeter.enable (
        lib.mkDefault true
      );
      assertions = [
        {
          assertion = !(cfg.services.displayManager.gdm.enable && cfg.services.greetd.enable);
          message = "GDM and greetd cannot both own the login screen. Select the preferred desktop or override one manager.";
        }
        {
          assertion = !cfg.services.displayManager.dms-greeter.enable || cfg.services.greetd.enable;
          message = "DMS greeter requires greetd.";
        }
        {
          assertion = !cfg.programs.dms-shell.enable || cfg.programs.niri.enable;
          message = "The Arch DMS session port requires Niri.";
        }
      ];
    }
  ];
}
