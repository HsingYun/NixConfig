{
  config,
  lib,
  ...
}:
let
  cfg = config.features.chinese;
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
  home = {
    language = {
      base = lib.mkDefault "zh_CN.UTF-8";
      messages = lib.mkDefault "zh_CN.UTF-8";
    };
    sessionVariables = {
      LANGUAGE = lib.mkDefault "zh_CN:en_US";
      QT_IM_MODULE = lib.mkDefault "fcitx";
      XMODIFIERS = lib.mkDefault "@im=fcitx";
      SDL_IM_MODULE = lib.mkDefault "fcitx";
      GLFW_IM_MODULE = lib.mkDefault "ibus";
    };
  };
  systemd = {
    user = {
      startServices = lib.mkDefault true;
      sessionVariables = lib.mapAttrs (_: lib.mkDefault) (
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
    };
  };
  gtk.enable = lib.mkDefault true;
  i18n.inputMethod = {
    enable = lib.mkDefault true;
    type = lib.mkDefault "fcitx5";
    fcitx5 = {
      waylandFrontend = lib.mkDefault true;
      inherit settings;
    };
  };
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
    # Chromium's UI requests Adwaita Sans by name. Give it an explicit CJK
    # fallback without replacing its Latin glyphs or relying on generic aliases.
    configFile.adwaita-cjk = {
      enable = true;
      priority = 60;
      settings = {
        description = "Use the preferred Chinese fonts for Adwaita Sans fallback";
        alias = {
          "@binding" = "same";
          family = "Adwaita Sans";
          accept.family = config.fonts.fontconfig.defaultFonts.sansSerif;
        };
      };
    };
  };
}
