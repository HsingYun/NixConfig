{
  config,
  lib,
  ...
}:
{
  imports = [
    ./services/default.nix
    ../activation
  ];
  options.native.requiredPackages = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    internal = true;
  };
  config = {
    software.requirements = lib.genAttrs (lib.unique config.native.requiredPackages) (_: {
      scopes = [ "system" ];
    });
    assertions = map (name: {
      assertion = config.software.resolved.${name}.provider == "pacman";
      message = "Arch system integration for '${name}' requires its native package (units, drivers or ABI); the selected provider cannot satisfy this contract.";
    }) (lib.unique config.native.requiredPackages);
  };
}
