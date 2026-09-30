{ lib, pkgs, ... }:
{
  software.requirements = lib.genAttrs (builtins.attrNames
    (import ../../../lib/software/profile-requirements.nix { inherit pkgs; }).devel
  ) (_: { });
}
