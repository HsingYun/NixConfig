{
  config,
  lib,
  ...
}:
let
  cfg = config.features.desktop.keyring;
  keyring = config.software.resolved.gnome-keyring;
  usesPacman = keyring.provider == "pacman";
in
{
  config = lib.mkIf cfg.enable {
    software.requirements.gnome-keyring.scopes = [ "home" ];
    assertions = [
      {
        assertion = !usesPacman || !config.services.gnome-keyring.enable;
        message = "Arch's keyring units own the daemon; disable Home Manager's services.gnome-keyring.";
      }
      {
        assertion = usesPacman || !(lib.hasInfix "/run/wrappers/bin" (keyring.package.postFixup or ""));
        message = "Standalone Nix keyring requires useWrappedDaemon=false.";
      }
    ];
    native.systemd.user.units = lib.mkIf usesPacman {
      "gnome-keyring-daemon.service".wantedBy = [ "default.target" ];
      "gnome-keyring-daemon.socket".wantedBy = [ "sockets.target" ];
    };
  };
}
