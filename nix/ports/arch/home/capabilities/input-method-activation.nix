{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Keep the native package from reintroducing autostart after the managed
  # Fcitx user service disappears. Do nothing on hosts that never enabled it.
  home.activation.nativeInputMethodAutostart = lib.mkIf (config.software.platform == "arch") (
    lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "linkGeneration" "installNativePackages" ] ''
      run ${pkgs.python3}/bin/python3 ${../../../../assets/helpers}/arch/autostart.py \
        ${lib.escapeShellArg "${config.xdg.configHome}/autostart/org.fcitx.Fcitx5.desktop"} \
        ${lib.escapeShellArg "${config.xdg.stateHome}/nixconfig/fcitx-autostart.sha256"} \
        ${
          if config.i18n.inputMethod.enable && config.i18n.inputMethod.fcitx5.systemd.enable then
            "true"
          else
            "false"
        } || exit $?
    ''
  );
}
