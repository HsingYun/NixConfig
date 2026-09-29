{ config, lib, ... }:
let
  packages = [
    "fcitx5"
    "fcitx5-rime"
    "fcitx5-gtk"
    "fcitx5-qt"
    "rime-ice"
  ];
in
{
  software.requirements = lib.genAttrs packages (_: { });
  assertions = [
    {
      assertion =
        config.software.packageManager.type == "pacman"
        && lib.all (name: config.software.resolved.${name}.provider == "pacman") packages;
      message = "Arch Chinese input uses native Fcitx and ABI-compatible native addons. Keep these packages on pacman.";
    }
    {
      assertion = !config.i18n.inputMethod.enable;
      message = "Arch Chinese input is managed by the native adapter; do not also enable Home Manager's Nix input-method runtime.";
    }
  ];
  systemd.user.services.fcitx5-daemon = {
    Unit = {
      Description = "Fcitx5 input method editor";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "/usr/bin/fcitx5";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
