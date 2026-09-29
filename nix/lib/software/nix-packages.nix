{ lib }:
let
  priority = package: package.meta.priority or lib.meta.defaultPriority;
  selectOutputs =
    package: outputs:
    if outputs == null then
      [ package ]
    else
      map (
        name:
        assert lib.assertMsg (
          package ? ${name}
        ) "Software: package '${lib.getName package}' does not provide required output '${name}'.";
        # Output attributes carry the derivation's original metadata. Preserve
        # priorities applied to the selected package, including user overrides.
        lib.setPrio (priority package) package.${name}
      ) outputs;
  installedOutputs =
    packages:
    lib.concatMap (
      package:
      if !(package.outputSpecified or false) && (package.meta.outputsToInstall or null) != null then
        selectOutputs package package.meta.outputsToInstall
      else
        [ package ]
    ) packages;
in
{
  inherit priority selectOutputs installedOutputs;
  sortByPriority = lib.sort (a: b: priority a < priority b);
}
