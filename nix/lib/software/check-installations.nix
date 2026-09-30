{ lib }:
{
  scope,
  packages,
  plan,
  runtimeArtifacts,
}:
let
  installed = map toString packages;
  present = package: builtins.elem (toString package) installed;
in
(import ./check-manifest.nix { inherit lib; } {
  provider = "nix";
  requested.${scope} = map toString plan.installations.nix.${scope + "Packages"};
  actual.${scope} = installed;
})
++ lib.mapAttrsToList (id: artifact: {
  assertion = !(builtins.elem scope artifact.scopes) || present artifact.package;
  message = "Software consumer '${id}' claims a ${scope} installation that its upstream module did not provide.";
}) runtimeArtifacts
