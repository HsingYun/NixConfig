{ lib }:
{
  selection,
  runtimePackages ? { },
}:
let
  resolved = lib.mapAttrs (
    name: entry:
    let
      boundPackage = runtimePackages.${name} or null;
      runtimePackage =
        if entry.provider != "nix" then
          null
        else if boundPackage != null then
          boundPackage
        else if entry.installNix then
          entry.package
        else
          null;
    in
    entry
    // {
      inherit runtimePackage;
      command =
        if entry.provider != "nix" then
          entry.command
        else if runtimePackage == null then
          executable: throw "Software: '${name}' has no active runtime package for '${executable}'."
        else
          executable: lib.getExe' runtimePackage executable;
    }
  ) selection.resolved;
  values = builtins.attrValues resolved;
  installationPlan = selection.planInstallations {
    installedOwners = builtins.attrNames (
      lib.filterAttrs (
        _: entry: entry.provider != "nix" || entry.installNix || entry.runtimePackage != null
      ) resolved
    );
    runtimePackages = lib.mapAttrs (_: entry: entry.runtimePackage) resolved;
  };

in
selection
// installationPlan
// {
  inherit resolved;
  # Only native search paths are added here. NixOS/HM buildEnv owns Nix
  # outputs, collisions and priorities; expose its profile, never raw bins.
  installations = installationPlan.installations // {
    nix = installationPlan.installations.nix // {
      modulePackages = lib.unique (
        map (entry: entry.runtimePackage) (
          lib.filter (entry: !entry.installNix && entry.runtimePackage != null) values
        )
      );
    };
  };
  report = lib.mapAttrs (
    name: entry:
    selection.report.${name}
    // {
      runtimePackage = if entry.runtimePackage == null then null else toString entry.runtimePackage;
    }
  ) resolved;
}
