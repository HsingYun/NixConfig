{
  config,
  lib,
  pkgs,
  ...
}:
let
  settings = config.i18n.inputMethod.fcitx5.settings;
  ini = pkgs.formats.ini { };
  addonIni = pkgs.formats.iniWithGlobalSection { };
  normalize =
    value:
    if builtins.isBool value then
      (if value then "True" else "False")
    else if builtins.isAttrs value then
      lib.mapAttrs (_: normalize) value
    else if builtins.isList value then
      map normalize value
    else
      value;
  packages = [
    "fcitx5"
    "fcitx5-rime"
    "fcitx5-gtk"
    "fcitx5-qt"
    "rime-ice"
  ];
in
{
  gtk = {
    gtk2.extraConfig = ''gtk-im-module="fcitx"'';
    gtk3.extraConfig.gtk-im-module = lib.mkDefault "fcitx";
    gtk4.extraConfig.gtk-im-module = lib.mkDefault "fcitx";
  };
  software.requirements = lib.genAttrs packages (_: { });
  xdg.configFile = {
    "fcitx5/profile".source = ini.generate "fcitx5-profile" (normalize settings.inputMethod);
    "fcitx5/config" = lib.mkIf (settings.globalOptions != { }) {
      source = ini.generate "fcitx5-config" (normalize settings.globalOptions);
    };
  }
  // lib.mapAttrs' (
    name: value:
    lib.nameValuePair "fcitx5/conf/${name}.conf" {
      source = addonIni.generate "fcitx5-${name}" (normalize value);
    }
  ) settings.addons;
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
