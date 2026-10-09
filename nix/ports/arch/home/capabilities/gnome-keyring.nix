# Keep HM's options and Nix implementation, adding Arch's native service branch.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  upstream = import "${inputs.home-manager}/modules/services/gnome-keyring.nix" {
    inherit config lib pkgs;
  };
  cfg = config.services.gnome-keyring;
  keyring = config.software.resolved.gnome-keyring;
  native = cfg.package == null;
in
{
  disabledModules = [ "services/gnome-keyring.nix" ];
  options =
    lib.recursiveUpdateUntil
      (
        _: left: right:
        lib.isOption left || lib.isOption right
      )
      upstream.options
      {
        services.gnome-keyring.package = upstream.options.services.gnome-keyring.package // {
          type = lib.types.nullOr upstream.options.services.gnome-keyring.package.type;
        };
      };
  config = lib.mkMerge [
    (lib.mkIf (!native) upstream.config)
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = !native || keyring.provider == "pacman";
          message = "Arch's native keyring service requires its pacman package.";
        }
        {
          assertion = native || !(lib.hasInfix "/run/wrappers/bin" (cfg.package.postFixup or ""));
          message = "Standalone Nix keyring requires useWrappedDaemon=false.";
        }
      ];
    })
    (lib.mkIf (cfg.enable && native) {
      assertions = [
        {
          assertion = !config.services.pass-secret-service.enable;
          message = "Only one secrets service per user can be enabled: gnome-keyring conflicts with pass-secret-service.";
        }
      ];
      native.systemd.user.units = {
        "gnome-keyring-daemon.service" = {
          wantedBy = [ "default.target" ];
          dropIns."nixconfig.conf".Service.ExecStart = [
            ""
            (lib.escapeShellArgs (
              [
                (keyring.command "gnome-keyring-daemon")
                "--foreground"
                "--control-directory=%t/keyring"
              ]
              ++ lib.optional (cfg.components != [ ]) ("--components=" + lib.concatStringsSep "," cfg.components)
            ))
          ];
        };
        "gnome-keyring-daemon.socket".wantedBy = [ "sockets.target" ];
      };
    })
  ];
}
