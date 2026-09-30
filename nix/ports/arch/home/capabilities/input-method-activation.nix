{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.i18n.inputMethod;
  mode =
    if !cfg.enable then
      "disabled"
    else if cfg.fcitx5.systemd.enable then
      "systemd"
    else
      "autostart";
in
{
  # Retiring input differs from handing startup back to the desktop.
  home.activation.nativeInputMethodAutostart = lib.mkIf (config.software.platform == "arch") (
    lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "linkGeneration" "installNativePackages" ] ''
      run ${pkgs.python3}/bin/python3 ${../../../../assets/helpers}/arch/autostart.py \
        ${lib.escapeShellArg "${config.xdg.configHome}/autostart/org.fcitx.Fcitx5.desktop"} \
        ${lib.escapeShellArg "${config.xdg.stateHome}/nixconfig/fcitx-autostart.sha256"} \
        ${mode} || exit $?
    ''
  );
}
