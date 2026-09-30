{
  config,
  lib,
  pkgs,
  ...
}:
let
  packages = [
    "networkmanager"
    "bluez"
    "bluez-utils"
    "pipewire"
    "pipewire-alsa"
    "pipewire-pulse"
    "wireplumber"
    "rtkit"
    "upower"
    "udisks2"
    "gvfs"
  ]
  ++ lib.optional config.features.desktop.gnome.enable "avahi";
  units = {
    "pipewire.service" = [ "default.target" ];
    "pipewire.socket" = [ "sockets.target" ];
    "pipewire-pulse.service" = [ "default.target" ];
    "pipewire-pulse.socket" = [ "sockets.target" ];
    "wireplumber.service" = [ "pipewire.service" ];
  };
  link = name: config.lib.file.mkOutOfStoreSymlink "/usr/lib/systemd/user/${name}";
in
{
  config =
    lib.mkIf
      (
        config.features.desktop.gnome.enable
        || config.features.desktop.niri.enable
        || config.features.desktop.dms.enable
      )
      {
        software.requirements = lib.genAttrs packages (_: { });
        assertions = [
          {
            assertion =
              config.software.packageManager.type == "pacman"
              && lib.all (name: config.software.resolved.${name}.provider == "pacman") packages;
            message = "Arch desktop session services require native packages and units.";
          }
        ];
        nativeSystemd = {
          enableOnly = [ "NetworkManager-wait-online.service" ];
          units = [
            "NetworkManager.service"
            "bluetooth.service"
          ]
          ++ lib.optionals config.features.desktop.gnome.enable [
            "avahi-daemon.service"
            "avahi-daemon.socket"
          ];
        };
        systemd.user.startServices = lib.mkDefault true;
        xdg.configFile =
          lib.concatMapAttrs (
            name: targets:
            {
              "systemd/user/${name}".source = link name;
            }
            // lib.listToAttrs (
              map (
                target: lib.nameValuePair "systemd/user/${target}.wants/${name}" { source = link name; }
              ) targets
            )
          ) units
          // {
            "systemd/user/pipewire-session-manager.service".source = link "wireplumber.service";
          };
        # Never bring up a second network manager or stop the current connection.
        # This read-only preflight also runs during dry-run, before package changes.
        home.activation.checkNativeDesktopNetwork = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
          ${pkgs.python3}/bin/python ${../../../../assets/helpers/network-preflight.py}
        '';
      };
}
