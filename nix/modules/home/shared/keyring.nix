{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.desktop.keyring;
  platform = config.software.platform;
  isNixos = builtins.elem platform [
    "nixos"
    "nixos-wsl"
  ];
  keyring = config.software.resolved.gnome-keyring;
  nativeUnits = keyring.provider == "pacman";
  nativeUnit = name: config.lib.file.mkOutOfStoreSymlink "/usr/lib/systemd/user/${name}";
  service = nativeUnit "gnome-keyring-daemon.service";
  socket = nativeUnit "gnome-keyring-daemon.socket";
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.software.packageManager.type != "pacman" || nativeUnits;
        message = "Arch keyring must use the native package for PAM, DBus and systemd integration; Nix package overrides are unsupported with pacman.";
      }
      {
        assertion = pkgs.stdenv.hostPlatform.isLinux;
        message = "features.desktop.keyring is only supported on Linux.";
      }
      {
        assertion = !config.services.gnome-keyring.enable;
        message = "features.desktop.keyring owns the keyring daemon; disable services.gnome-keyring to avoid a second instance.";
      }
      {
        assertion = !isNixos || toString keyring.package == toString pkgs.gnome-keyring;
        message = "NixOS keyring must use pkgs.gnome-keyring consistently for PAM, DBus and its capability wrapper. Customize it through a system nixpkgs overlay, not a Home Manager package override.";
      }
      {
        assertion =
          nativeUnits || isNixos || !(lib.hasInfix "/run/wrappers/bin" (keyring.package.postFixup or ""));
        message = "Standalone Nix keyring requires useWrappedDaemon=false. Set software.packageOverrides.gnome-keyring = pkgs.gnome-keyring.override { useWrappedDaemon = false; };";
      }
    ];

    software.requirements.gnome-keyring.scopes = [ (if isNixos then "system" else "home") ];
    # Standalone Nix installations have no NixOS capability wrapper. Their
    # DBus and autostart entries must point to the package's own executable.
    software.packageOverrides =
      lib.mkIf (platform == "arch" && config.software.packageManager.type == "nix")
        {
          gnome-keyring = lib.mkDefault (pkgs.gnome-keyring.override { useWrappedDaemon = false; });
        };

    systemd.user.startServices = lib.mkDefault true;

    # Arch's package already owns the daemon, socket activation and PAM module.
    xdg.configFile = lib.mkIf nativeUnits {
      "systemd/user/gnome-keyring-daemon.service".source = service;
      "systemd/user/gnome-keyring-daemon.socket".source = socket;
      "systemd/user/default.target.wants/gnome-keyring-daemon.service".source = service;
      "systemd/user/sockets.target.wants/gnome-keyring-daemon.socket".source = socket;
    };

    # nixpkgs disables upstream systemd support, so supply a session service.
    systemd.user.services.gnome-keyring-daemon = lib.mkIf (!nativeUnits) {
      Unit = {
        Description = "GNOME Keyring daemon";
        Before = [ "graphical-session-pre.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${keyring.command "gnome-keyring-daemon"} --start --foreground --components=pkcs11,secrets";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session-pre.target" ];
    };
  };
}
