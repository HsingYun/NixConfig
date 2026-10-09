{ config, lib, ... }:
let
  cfg = config.i18n.inputMethod;
  packages = [
    "fcitx5-rime"
    "rime-ice"
  ];
in
{
  # The Chinese preset supplies the engine and dictionaries; the Fcitx port
  # remains usable with other native input methods and without AUR dependencies.
  config = lib.mkIf (cfg.enable && cfg.type == "fcitx5") {
    software.requirements = lib.genAttrs packages (_: { });
    assertions = [
      {
        assertion = lib.all (name: config.software.resolved.${name}.provider == "pacman") packages;
        message = "Arch Chinese input requires native Rime and Rime Ice for the native Fcitx5 runtime. Keep these packages on pacman.";
      }
    ];
  };
}
