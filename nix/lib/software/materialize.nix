{ lib }:
{
  selection,
  runtimeArtifacts ? { },
}:
let
  artifactsFor =
    name: lib.filter (artifact: artifact.software == name) (builtins.attrValues runtimeArtifacts);
  runtimePackages = lib.mapAttrs (
    name: _:
    let
      packages = lib.unique (map (artifact: artifact.package) (artifactsFor name));
    in
    assert lib.assertMsg (builtins.length (lib.unique (map toString packages)) <= 1)
      "Software '${name}': active consumers produce different final packages; use compatible upstream consumers or separate software identities.";
    if packages == [ ] then null else builtins.head packages
  ) selection.resolved;
  runtimeScopes = lib.mapAttrs (
    name: _: lib.unique (lib.concatMap (artifact: artifact.scopes) (artifactsFor name))
  ) selection.resolved;
  resolved = lib.mapAttrs (
    name: entry:
    let
      boundPackage = runtimePackages.${name};
      runtimePackage =
        if entry.provider != "nix" then
          null
        else if boundPackage != null then
          boundPackage
        else if entry.scopes != [ ] then
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
  installationPlan = selection.planInstallations {
    inherit runtimePackages runtimeScopes;
    installedOwners = builtins.attrNames (
      lib.filterAttrs (
        name: entry: entry.provider != "nix" || entry.scopes != [ ] || runtimeScopes.${name} != [ ]
      ) resolved
    );
  };
in
selection
// installationPlan
// {
  inherit resolved;
  installations =
    assert lib.assertMsg (lib.all (artifact: selection.resolved ? ${artifact.software}) (
      builtins.attrValues runtimeArtifacts
    )) "Software: a runtime consumer has no software requirement.";
    installationPlan.installations
    // {
      nix = installationPlan.installations.nix // {
        modulePackages = lib.unique (
          map (artifact: artifact.package) (
            lib.filter (artifact: artifact.scopes != [ ]) (builtins.attrValues runtimeArtifacts)
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
