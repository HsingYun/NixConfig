{ lib, pkgs, ... }:
let
  ini = (pkgs.formats.ini { }).type;
  addonIni = (pkgs.formats.iniWithGlobalSection { }).type;
  settings =
    type:
    lib.mkOption {
      inherit type;
      default = { };
    };
in
{
  options.i18n.inputMethod = {
    enable = lib.mkEnableOption "input method";
    type = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    fcitx5 = {
      addons = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
      };
      waylandFrontend = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      systemd.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      sessionVariables = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {
          GLFW_IM_MODULE = "ibus";
          SDL_IM_MODULE = "fcitx";
          XMODIFIERS = "@im=fcitx";
        };
      };
      settings = {
        inputMethod = settings ini;
        globalOptions = settings ini;
        addons = settings (lib.types.attrsOf addonIni);
      };
    };
  };
}
