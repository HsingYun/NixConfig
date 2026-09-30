{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.i18n.inputMethod;
  settings = cfg.fcitx5.settings;
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
  optionalFile =
    name: format: value:
    lib.optionalAttrs (value != { }) {
      "fcitx5/${name}".source = format.generate "fcitx5-${builtins.replaceStrings [ "/" ] [ "-" ] name}" (
        normalize value
      );
    };
  packages = [
    "fcitx5"
    "fcitx5-rime"
    "fcitx5-gtk"
    "fcitx5-qt"
    "rime-ice"
  ];
in
{
  disabledModules = [ "i18n/input-method/default.nix" ];
  imports = [
    ./input-method-activation.nix
    ../../../../contracts/home/input-method.nix
  ];
  config = lib.mkIf cfg.enable {
    home.sessionVariables =
      cfg.fcitx5.sessionVariables
      // lib.optionalAttrs (!cfg.fcitx5.waylandFrontend) {
        GTK_IM_MODULE = "fcitx";
        QT_IM_MODULE = "fcitx";
      };
    gtk = lib.mkIf cfg.fcitx5.waylandFrontend {
      gtk2.extraConfig = ''gtk-im-module="fcitx"'';
      gtk3.extraConfig.gtk-im-module = lib.mkDefault "fcitx";
      gtk4.extraConfig.gtk-im-module = lib.mkDefault "fcitx";
    };
    software.requirements = lib.genAttrs packages (_: { });
    xdg.configFile =
      optionalFile "profile" ini settings.inputMethod
      // optionalFile "config" ini settings.globalOptions
      // lib.concatMapAttrs (name: optionalFile "conf/${name}.conf" addonIni) settings.addons;
    assertions = [
      {
        assertion = lib.all (name: config.software.resolved.${name}.provider == "pacman") packages;
        message = "Arch Chinese input uses native Fcitx and ABI-compatible native addons. Keep these packages on pacman.";
      }
      {
        assertion = cfg.type == "fcitx5" && cfg.fcitx5.addons == [ ];
        message = "Arch input-method port supports native Fcitx5; Nix addon derivations cannot be loaded into its native ABI. Use native extraPkg for additional addons.";
      }
    ];
    systemd.user.services.fcitx5-daemon = lib.mkIf cfg.fcitx5.systemd.enable {
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
  };
}
