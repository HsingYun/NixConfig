{
  config,
  lib,
  software,
  ...
}:

{
  software.requirements =
    lib.genAttrs [ "noto-cjk-sans" "noto-cjk-serif" "noto-emoji" "maple-mono" ] (_: { })
    // {
      fcitx5-rime = {
        capabilities = [ "store-package" ];
        installNix = false;
      };
    };
  home.language = {
    base = lib.mkDefault "zh_CN.UTF-8";
    messages = lib.mkDefault "zh_CN.UTF-8";
  };
  home.sessionVariables = {
    LANGUAGE = lib.mkDefault "zh_CN:en_US";
    QT_IM_MODULE = lib.mkDefault "fcitx";
  };

  systemd.user.sessionVariables = lib.mapAttrs (_: lib.mkDefault) (
    lib.filterAttrs (
      name: _:
      builtins.elem name [
        "LANG"
        "LC_MESSAGES"
        "LANGUAGE"
        "GTK_IM_MODULE"
        "QT_IM_MODULE"
        "XMODIFIERS"
        "SDL_IM_MODULE"
        "GLFW_IM_MODULE"
      ]
    ) config.home.sessionVariables
  );

  gtk.enable = lib.mkDefault true;
  i18n.inputMethod = {
    enable = lib.mkDefault true;
    type = lib.mkDefault "fcitx5";
    fcitx5 = {
      waylandFrontend = lib.mkDefault true;
      addons = [ software.fcitx5-rime.package ];
      settings.inputMethod = {
        GroupOrder."0" = lib.mkDefault "Default";
        "Groups/0" = {
          Name = lib.mkDefault "Default";
          "Default Layout" = lib.mkDefault "us";
          DefaultIM = lib.mkDefault "rime";
        };
        "Groups/0/Items/0".Name = lib.mkDefault "keyboard-us";
        "Groups/0/Items/1".Name = lib.mkDefault "rime";
      };
    };
  };

  xdg.dataFile."fcitx5/rime/default.custom.yaml".text = lib.mkDefault ''
    patch:
      __include: rime_ice_suggestion:/
      schema_list:
        - schema: rime_ice
  '';

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
