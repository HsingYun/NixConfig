{ lib }:
{
  entryOptions = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Generate this managed autostart entry.";
    };
    command = lib.mkOption {
      type = lib.types.addCheck (lib.types.nonEmptyListOf lib.types.str) (argv: builtins.head argv != "");
      description = "Executable and literal arguments, without shell expansion.";
    };
    environment = lib.mkOption {
      type = lib.types.addCheck (lib.types.attrsOf lib.types.str) (
        env: lib.all (key: builtins.match "[A-Za-z_][A-Za-z0-9_]*" key != null) (builtins.attrNames env)
      );
      default = { };
      description = "Literal process environment, stored in the Nix store.";
    };
    workingDirectory = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "/.*");
      default = null;
      description = "Absolute working directory, or null to inherit the session launcher directory.";
    };
  };
  validateNames =
    entries:
    assert lib.assertMsg
      (lib.all (name: builtins.match "[A-Za-z0-9_-][A-Za-z0-9_.-]*" name != null) (
        builtins.attrNames entries
      ))
      "Autostart entry names must start with a letter, digit, underscore or hyphen and contain only letters, digits, underscores, hyphens and dots.";
    entries;
}
