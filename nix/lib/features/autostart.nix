{ lib }:
let
  schema = import ../desktop/autostart.nix { inherit lib; };
in
{
  default = { };
  description = "Named login entries, each selecting an application role or an explicit command. Applications are installed separately.";
  type = lib.types.attrsOf (
    lib.types.submodule {
      options = schema.entryOptions // {
        command = lib.mkOption {
          type = lib.types.nullOr schema.entryOptions.command.type;
          default = null;
          description = "Explicit command, mutually exclusive with application.";
        };
        application = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              "terminal"
              "browser"
              "fileManager"
            ]
          );
          default = null;
          description = "Selected application role, mutually exclusive with command.";
        };
      };
    }
  );
  apply =
    entries:
    schema.validateNames (
      lib.mapAttrs (
        name: entry:
        assert lib.assertMsg (
          !entry.enable || ((entry.command != null) != (entry.application != null))
        ) "Autostart entry '${name}' must specify exactly one of command or application.";
        entry
      ) entries
    );
}
