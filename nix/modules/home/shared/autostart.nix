{ lib, ... }:
{
  options.desktop.autostart.entries = lib.mkOption {
    default = { };
    description = "Named desktop login commands. Applications must be installed separately; the desktop.autostart feature enables generation.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Generate this managed autostart entry.";
          };
          command = lib.mkOption {
            type = lib.types.addCheck (lib.types.nonEmptyListOf lib.types.str) (argv: builtins.head argv != "");
            description = "Executable and literal arguments, without shell expansion. Use an absolute executable path or a command available in the desktop session PATH.";
          };
          environment = lib.mkOption {
            type = lib.types.addCheck (lib.types.attrsOf lib.types.str) (
              env: lib.all (key: builtins.match "[A-Za-z_][A-Za-z0-9_]*" key != null) (builtins.attrNames env)
            );
            default = { };
            description = "Environment variables for this process; values are literal and stored in the Nix store.";
          };
          workingDirectory = lib.mkOption {
            type = lib.types.nullOr (lib.types.strMatching "/.*");
            default = null;
            description = "Absolute working directory, or null to inherit the session launcher directory. A missing directory prevents startup.";
          };
        };
      }
    );
    apply =
      entries:
      assert lib.assertMsg
        (lib.all (name: builtins.match "[A-Za-z0-9_-][A-Za-z0-9_.-]*" name != null) (
          builtins.attrNames entries
        ))
        "desktop.autostart.entries names must start with a letter, digit, underscore or hyphen and contain only letters, digits, underscores, hyphens and dots.";
      entries;
  };
}
