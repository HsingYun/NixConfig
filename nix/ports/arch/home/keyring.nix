{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.desktop.keyring;
  keyring = config.software.resolved.gnome-keyring;
  usesPacman = keyring.provider == "pacman";
  unit = name: config.lib.file.mkOutOfStoreSymlink "/usr/lib/systemd/user/${name}";
  service = unit "gnome-keyring-daemon.service";
  socket = unit "gnome-keyring-daemon.socket";
in
{
  config = lib.mkIf cfg.enable {
    software.requirements.gnome-keyring.scopes = [ "home" ];
    assertions = [
      {
        assertion = config.software.packageManager.type != "pacman" || usesPacman;
        message = "Arch keyring PAM, DBus and systemd integration requires the pacman package.";
      }
      {
        assertion = !usesPacman || !config.services.gnome-keyring.enable;
        message = "Arch's keyring units own the daemon; disable Home Manager's services.gnome-keyring.";
      }
      {
        assertion = usesPacman || !(lib.hasInfix "/run/wrappers/bin" (keyring.package.postFixup or ""));
        message = "Standalone Nix keyring requires useWrappedDaemon=false.";
      }
    ];
    software.packageOverrides = lib.mkIf (config.software.packageManager.type == "nix") {
      gnome-keyring = lib.mkDefault (pkgs.gnome-keyring.override { useWrappedDaemon = false; });
    };
    xdg.configFile = lib.mkIf usesPacman {
      "systemd/user/gnome-keyring-daemon.service".source = service;
      "systemd/user/gnome-keyring-daemon.socket".source = socket;
      "systemd/user/default.target.wants/gnome-keyring-daemon.service".source = service;
      "systemd/user/sockets.target.wants/gnome-keyring-daemon.socket".source = socket;
    };
  };
}
