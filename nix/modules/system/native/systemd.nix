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
  definitions = lib.mapAttrs (
    name: settings: toString ((pkgs.formats.systemd { }).generate name settings)
  ) config.native.systemd.definitions;
  manifest = pkgs.writeText "native-systemd-units.json" (
    builtins.toJSON { inherit units enableOnly definitions; }
  );
  state = "/var/lib/nixconfig/native-systemd/state.json";
in
{
  options = {
    native.systemd = {
      definitions = lib.mkOption {
        type = lib.types.attrsOf (pkgs.formats.systemd { }).type;
        default = { };
        description = "Owned concrete system unit definitions; template files are not supported.";
        apply =
          value:
          assert lib.assertMsg
            (lib.all (
              name:
              builtins.match "[A-Za-z0-9_@.+:-]+\\.(service|socket|timer|path)" name != null
              && !(lib.hasInfix "@." name)
            ) (lib.attrNames value))
            "Native systemd definitions require plain, concrete unit filenames; template definitions are not supported.";
          value;
      };
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
    native.resources.services = {
      desired = { inherit units enableOnly definitions; };
      check = ''
        ${pkgs.python3}/bin/python3 ${../../../assets/helpers}/common/systemd.py --check --units ${manifest}
      '';
    };
    # Keep reconciliation when the final service request disappears.
    native.activation.nativeSystemd = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if ${
        if units != [ ] || enableOnly != [ ] || definitions != { } then "true" else "test -f ${state}"
      }; then
        run ${lib.escapeShellArgs config.native.privilegeCommand} ${pkgs.python3}/bin/python3 ${../../../assets/helpers}/common/systemd.py \
          --owner ${lib.escapeShellArg user.username} --units ${manifest} || exit $?
      fi
    '';
  };
}
