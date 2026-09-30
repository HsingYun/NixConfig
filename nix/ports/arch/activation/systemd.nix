{
  config,
  lib,
  pkgs,
  user,
  ...
}:
let
  units = lib.sort builtins.lessThan (lib.unique config.native.systemd.units);
  enableOnly = lib.sort builtins.lessThan (lib.unique config.native.systemd.enableOnly);
  manifest = pkgs.writeText "native-systemd-units.json" (
    builtins.toJSON { inherit units enableOnly; }
  );
  state = "/var/lib/nixconfig/native-systemd/state.json";
in
{
  options = {
    native.systemd = {
      enableOnly = lib.mkOption {
        type = lib.types.listOf (lib.types.strMatching "[A-Za-z0-9_@.+:-]+\\.(service|socket|timer|path)");
        default = [ ];
        description = "Native units to enable for their target without starting immediately (for example boot-time oneshots).";
      };
      units = lib.mkOption {
        type = lib.types.listOf (lib.types.strMatching "[A-Za-z0-9_@.+:-]+\\.(service|socket|timer|path)");
        default = [ ];
        description = "Native system units required by the enabled platform adapters. Shared requirements are merged before activation.";
      };
    };
  };
  config = {
    # Keep reconciliation when the last feature or pacman adapter is disabled.
    native.activation.nativeSystemd =
      lib.hm.dag.entryAfter [ "installNativePackages" "linkGeneration" "nativeSmartcard" ]
        ''
          if ${if units != [ ] || enableOnly != [ ] then "true" else "test -f ${state}"}; then
            run /usr/bin/sudo ${pkgs.python3}/bin/python3 ${../../../assets/helpers}/arch/native-systemd.py \
              --owner ${lib.escapeShellArg user.username} --units ${manifest} || exit $?
          fi
        '';
  };
}
