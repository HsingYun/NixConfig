{ lib, pkgs, ... }:
{
  software.requirements = lib.genAttrs (builtins.attrNames
    (import ../../../lib/software/profiles.nix { inherit pkgs; }).devel
  ) (_: { });
}
