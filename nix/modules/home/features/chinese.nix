{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.chinese;
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
  settings = lib.recursiveUpdate {
    inputMethod = {
      GroupOrder."0" = "Default";
      "Groups/0" = {
        Name = "Default";
        "Default Layout" = "us";
        DefaultIM = "rime";
      };
      # Match the working native setup: Rime owns Chinese/English switching.
      "Groups/0/Items/0".Name = "rime";
    };
    globalOptions = { };
    addons = { };
  } cfg.settings;
in
{
  software.requirements = lib.genAttrs [
    "noto-cjk-sans"
    "noto-cjk-serif"
    "noto-emoji"
    "maple-mono"
  ] (_: { });
  home.language = {
    base = lib.mkDefault "zh_CN.UTF-8";
    messages = lib.mkDefault "zh_CN.UTF-8";
  };
  home.sessionVariables = {
    LANGUAGE = lib.mkDefault "zh_CN:en_US";
    QT_IM_MODULE = lib.mkDefault "fcitx";
    XMODIFIERS = lib.mkDefault "@im=fcitx";
    SDL_IM_MODULE = lib.mkDefault "fcitx";
    GLFW_IM_MODULE = lib.mkDefault "ibus";
  };
  systemd.user.startServices = lib.mkDefault true;
  systemd.user.sessionVariables = lib.mapAttrs (_: lib.mkDefault) (
    lib.filterAttrs (
      name: _:
      builtins.elem name [
        "LANG"
        "LC_MESSAGES"
        "LANGUAGE"
        "QT_IM_MODULE"
        "XMODIFIERS"
        "SDL_IM_MODULE"
        "GLFW_IM_MODULE"
      ]
    ) config.home.sessionVariables
  );
  gtk = {
    enable = lib.mkDefault true;
    gtk2.extraConfig = lib.mkIf (config.software.platform == "arch") ''gtk-im-module="fcitx"'';
    gtk3.extraConfig.gtk-im-module = lib.mkIf (config.software.platform == "arch") (
      lib.mkDefault "fcitx"
    );
    gtk4.extraConfig.gtk-im-module = lib.mkIf (config.software.platform == "arch") (
      lib.mkDefault "fcitx"
    );
  };
  xdg.configFile = {
    "fcitx5/profile".source = ini.generate "fcitx5-profile" (normalize settings.inputMethod);
    "fcitx5/config" = lib.mkIf (settings.globalOptions != { }) {
      source = ini.generate "fcitx5-config" (normalize settings.globalOptions);
    };
    # One owner starts Fcitx: the session-bound user service on both platforms.
    "autostart/org.fcitx.Fcitx5.desktop" = lib.mkIf (config.software.platform != "arch") {
      text = ''
        [Desktop Entry]
        Type=Application
        Name=Fcitx 5
        Hidden=true
      '';
    };
  }
  // lib.mapAttrs' (
    name: value:
    lib.nameValuePair "fcitx5/conf/${name}.conf" {
      source = addonIni.generate "fcitx5-${name}" (normalize value);
    }
  ) settings.addons;
  xdg.dataFile = {
    "fcitx5/rime/default.custom.yaml".text = ''
      patch:
        __include: rime_ice_suggestion:/
    '';
    "fcitx5/rime/rime_ice.custom.yaml".text = ''
      patch:
        "switches/@0/reset": ${if cfg.englishByDefault then "1" else "0"}
    '';
  };
  fonts.fontconfig = {
    enable = lib.mkDefault true;
    defaultFonts = {
      sansSerif = lib.mkDefault [ "Noto Sans CJK SC" ];
      serif = lib.mkDefault [ "Noto Serif CJK SC" ];
      monospace = lib.mkDefault [ "Maple Mono NF CN" ];
      emoji = lib.mkDefault [ "Noto Color Emoji" ];
    };
  };
}
