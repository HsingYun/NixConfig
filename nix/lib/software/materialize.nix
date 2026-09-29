{ lib }:
{
  selection,
  runtimePackages ? { },
}:
let
  nixPackages = import ./nix-packages.nix { inherit lib; };
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
      runtimeOutputs =
        if runtimePackage == null then
          [ ]
        else
          nixPackages.installedOutputs (
            if toString runtimePackage == toString entry.package then entry.packages else [ runtimePackage ]
          );
    in
    entry
    // {
      inherit runtimePackage runtimeOutputs;
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
  installationPlan = selection.planInstallations (
    builtins.attrNames (
      lib.filterAttrs (
        _: entry: entry.provider != "nix" || entry.installNix || entry.runtimePackage != null
      ) resolved
    )
  );
  selectedOutputs = lib.concatMap (entry: entry.runtimeOutputs) values;
  externalPaths = map toString installationPlan.externalNixPackages;
  # Final wrappers may have a different priority than their input package.
  # Keep extras below those wrappers in both the profile and the runtime PATH.
  externalPriority =
    1 + lib.foldl' lib.max lib.meta.defaultPriority (map nixPackages.priority selectedOutputs);
  finalizePackages = map (
    package:
    if builtins.elem (toString package) externalPaths then
      lib.setPrio externalPriority package
    else
      package
  );
  nixInstallation = installationPlan.installations.nix // {
    homePackages = finalizePackages installationPlan.installations.nix.homePackages;
    systemPackages = finalizePackages installationPlan.installations.nix.systemPackages;
    modulePackages = lib.unique (
      map (entry: entry.runtimePackage) (
        lib.filter (entry: !entry.installNix && entry.runtimePackage != null) values
      )
    );
  };
  # Use the priorities and output selection of the installed profile, including
  # final module wrappers, rather than the alphabetical order of software IDs.
  runtimeBinPaths = map (package: "${package}/bin") (
    nixPackages.sortByPriority (
      lib.unique (
        selectedOutputs
        ++ nixPackages.installedOutputs (nixInstallation.homePackages ++ nixInstallation.systemPackages)
      )
    )
  );
in
selection
// installationPlan
// {
  inherit resolved;
  # Protect selected Nix commands even when an old native installation remains.
  binPaths = lib.unique (
    runtimeBinPaths ++ installationPlan.selectedBinPaths ++ installationPlan.externalBinPaths
  );
  installations = installationPlan.installations // {
    nix = nixInstallation;
  };
  report = lib.mapAttrs (
    name: entry:
    selection.report.${name}
    // {
      runtimePackage = if entry.runtimePackage == null then null else toString entry.runtimePackage;
    }
  ) resolved;
}
