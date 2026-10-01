{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.native.systemd.user.units;
  format = pkgs.formats.systemd { };
  unitName = lib.types.strMatching "[A-Za-z0-9_@.+:-]+\\.(service|socket|target|timer|path|slice|mount|automount)";
  units = lib.filterAttrs (_: unit: unit.enable) cfg;
in
{
  options.native.systemd.user.vendorDirectory = lib.mkOption {
    type = lib.types.strMatching "/.*";
    description = "Port-provided directory containing native systemd user units.";
  };
  options.native.systemd.user.units = lib.mkOption {
    default = { };
    description = "Native vendor user units linked and activated through Home Manager.";
    apply =
      value:
      assert lib.assertMsg (lib.all unitName.check (
        lib.attrNames value
      )) "native.systemd.user.units requires plain unit filenames.";
      value;
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to manage this vendor unit and its links.";
          };
          wantedBy = lib.mkOption {
            type = lib.types.listOf unitName;
            default = [ ];
            description = "Units whose wants directories should contain this unit.";
          };
          requiredBy = lib.mkOption {
            type = lib.types.listOf unitName;
            default = [ ];
            description = "Units whose requires directories should contain this unit.";
          };
          aliases = lib.mkOption {
            type = lib.types.listOf unitName;
            default = [ ];
            description = "Additional names for this vendor unit.";
          };
          dropIns = lib.mkOption {
            type = lib.types.attrsOf format.type;
            apply =
              value:
              assert lib.assertMsg (lib.all (name: builtins.match "[A-Za-z0-9_.-]+\\.conf" name != null) (
                lib.attrNames value
              )) "Native user unit drop-ins require plain .conf filenames.";
              value;
            default = { };
            description = "Named, structured systemd drop-ins; names include the .conf suffix.";
          };
        };
      }
    );
  };

  config = lib.mkIf (units != { }) {
    systemd.user.startServices = lib.mkDefault true;
    # Keep vendor contents authoritative. Defining an HM service here would
    # replace the main unit instead of extending the distribution's installed unit.
    # Separate module definitions also reject competing alias/link owners.
    xdg.configFile = lib.mkMerge (
      lib.mapAttrsToList (
        name: unit:
        let
          source = config.lib.file.mkOutOfStoreSymlink "${config.native.systemd.user.vendorDirectory}/${name}";
          links = [
            name
          ]
          ++ unit.aliases
          ++ map (target: "${target}.wants/${name}") unit.wantedBy
          ++ map (target: "${target}.requires/${name}") unit.requiredBy;
        in
        lib.genAttrs (map (path: "systemd/user/${path}") links) (_: {
          inherit source;
        })
        // lib.mapAttrs' (
          filename: settings:
          lib.nameValuePair "systemd/user/${name}.d/${filename}" {
            source = format.generate "${name}-${filename}" settings;
          }
        ) unit.dropIns
      ) units
    );
  };
}
