# Interpret nixpkgs' script metadata before selecting the player. Explicit
# native adapters may satisfy known wrapper requirements; unknown ones use Nix.
{ lib }:
{
  scripts,
  adapters ? { },
}:
let
  matches =
    adapter: script:
    toString adapter.package == toString script
    && adapter.wrapperArgs == (script.extraWrapperArgs or [ ]);
  declarations = builtins.attrValues adapters;
  # All matching declarations contribute; ordinary module merging diagnoses
  # conflicting settings instead of choosing an adapter by alphabetical order.
  activeAdapters = lib.filter (adapter: lib.any (matches adapter) scripts) declarations;
in
{
  requiresWrapper = lib.any (
    script:
    (script.extraWrapperArgs or [ ]) != [ ] && !(lib.any (adapter: matches adapter script) declarations)
  ) scripts;
  fontDirectories = lib.unique (lib.concatMap (script: script.fontDirectories or [ ]) scripts);
  scriptOpts = map (adapter: adapter.scriptOpts) activeAdapters;
  paths = lib.concatMap (
    script:
    map (name: "${script}/share/mpv/scripts/${name}") (
      [ script.scriptName ] ++ (script.extraScriptsToLoad or [ ])
    )
  ) scripts;
}
