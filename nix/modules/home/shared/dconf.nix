{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dconf;
  values =
    settings:
    lib.concatMapAttrs (
      section: entries:
      lib.mapAttrs' (
        key: value: lib.nameValuePair "/${section}/${key}" (toString (lib.hm.gvariant.mkValue value))
      ) entries
    ) settings;
  manifest = pkgs.writeText "managed-dconf.json" (
    builtins.toJSON (
      lib.optionalAttrs cfg.enable (
        { "" = values cfg.settings; } // lib.mapAttrs (_: values) cfg.databases
      )
    )
  );
  python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
  command = "${python}/bin/python3 ${../../../assets/helpers}/dconf.py ${manifest} ${lib.escapeShellArg "${config.xdg.stateHome}/nixconfig/dconf.json"} ${pkgs.dconf}/bin/dconf";
in
{
  assertions = lib.optional cfg.enable {
    assertion = lib.all (name: builtins.match "[A-Za-z0-9_]+" name != null) (
      builtins.attrNames cfg.databases
    );
    message = "dconf database names must be valid DBus object path components (letters, digits and underscores).";
  };
  # Replace upstream's key-only cleanup so the last removal is still reconciled,
  # and external edits are preserved instead of indiscriminately resetting keys.
  home.activation.dconfSettings = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.mkForce (
      lib.hm.dag.entryAfter [ "installPackages" ] ''
        if ${if cfg.enable && (cfg.settings != { } || cfg.databases != { }) then "true" else "false"} ||
           [[ -f ${lib.escapeShellArg "${config.xdg.stateHome}/nixconfig/dconf.json"} ]] ||
           [[ -n ''${oldGenPath:-} && -f "$oldGenPath/state/dconf-keys.json" ]]; then
        if [[ -v DBUS_SESSION_BUS_ADDRESS ]]; then
          run env GI_TYPELIB_PATH=${pkgs.glib.out}/lib/girepository-1.0 ${command} "''${oldGenPath:-}" || exit $?
        else
          run env XDG_DATA_DIRS="${pkgs.dconf}/share:''${XDG_DATA_DIRS:-}" ${pkgs.dbus}/bin/dbus-run-session --dbus-daemon=${pkgs.dbus}/bin/dbus-daemon --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- env GI_TYPELIB_PATH=${pkgs.glib.out}/lib/girepository-1.0 ${command} "''${oldGenPath:-}" || exit $?
        fi
        fi
      ''
    )
  );
}
