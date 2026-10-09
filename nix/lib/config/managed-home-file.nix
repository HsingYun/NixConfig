# Read the final HM deployment, after XDG translation and host overrides.
# Consumers share HM's source snapshot semantics instead of validating an
# earlier declaration or a mutable local file that will not be deployed.
{ lib }:
{ home, name }:
let
  file = home.home.file.${name} or null;
  enable = file != null && file.enable;
in
{
  inherit enable;
  source =
    if !enable then
      null
    else if builtins.hasContext (toString file.source) then
      file.source
    else
      builtins.path {
        path = file.source;
        name = home.lib.strings.storeFileName (baseNameOf (toString file.source));
      };
  target =
    if !enable then
      null
    else if lib.hasPrefix "/" file.target then
      file.target
    else
      "${home.home.homeDirectory}/${file.target}";
}
