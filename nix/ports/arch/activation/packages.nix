{
  config,
  lib,
  pkgs,
  ...
}:
let
  catalog = import ../../../lib/software/catalog.nix { inherit pkgs; };
  replacementNames = lib.unique (
    lib.concatMap (
      name:
      lib.optional (
        config.software.resolved ? ${name}
        && config.software.resolved.${name}.provider == "nix"
        && config.software.resolved.${name}.runtimePackage != null
        && catalog.${name} ? pacman
      ) catalog.${name}.pacman.name
    ) config.software.migration.removeReplaced
  );
  plan = config.software.plan.installations.pacman;
  replacements = lib.subtractLists (plan.packages ++ plan.aur) replacementNames;
in
{
  native.activation = {
    removeReplacedNativePackages =
      lib.mkIf
        (
          config.software.platform == "arch"

          && replacements != [ ]
        )
        (
          lib.hm.dag.entryBetween
            [ "linkGeneration" ]
            [ "installPackages" "systemProfile" "installNativePackages" ]
            (
              import ../../../assets/helpers/arch/pacman-migration.nix { inherit lib; } {
                packages = replacements;
              }
            )
        );
    installNativePackages = lib.mkIf (plan.packages != [ ] || plan.aur != [ ]) (
      lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] (
        import ../../../assets/helpers/arch/pacman-activation.nix { inherit lib; } plan
      )
    );
  };
}
