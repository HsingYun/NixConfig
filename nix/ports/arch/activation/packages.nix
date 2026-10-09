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
  native.resources.packages = {
    desired = plan // {
      remove = replacements;
    };
    check = ''
      installed=$(/usr/bin/pacman -Qq)
      for package in ${lib.escapeShellArgs (plan.packages ++ plan.aur)}; do
        ${pkgs.gnugrep}/bin/grep -Fxq -- "$package" <<< "$installed" || {
          echo "Missing native package: $package" >&2; exit 1;
        }
      done
      for package in ${lib.escapeShellArgs replacements}; do
        if ${pkgs.gnugrep}/bin/grep -Fxq -- "$package" <<< "$installed"; then
          echo "Native-to-Nix replacement still installed: $package" >&2; exit 1
        fi
      done
    '';
  };
  native.activation = {
    removeReplacedNativePackages = lib.mkIf (replacements != [ ]) (
      lib.hm.dag.entryBetween
        [ "linkGeneration" ]
        [ "installPackages" "systemProfile" "installNativePackages" ]
        (
          import ../../../assets/helpers/arch/pacman-migration.nix { inherit lib; } {
            inherit (config.native) privilegeCommand;
            packages = replacements;
          }
        )
    );
    installNativePackages = lib.mkIf (plan.packages != [ ] || plan.aur != [ ]) (
      lib.hm.dag.entryBetween [ "linkGeneration" "systemProfile" ] [ "writeBoundary" ] (
        import ../../../assets/helpers/arch/pacman-activation.nix { inherit lib pkgs; } (
          plan // { inherit (config.native) privilegeCommand; }
        )
      )
    );
  };
}
