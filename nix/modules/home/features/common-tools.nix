{ lib, pkgs, ... }:
{
  software.requirements = lib.genAttrs (
    builtins.attrNames
      (import ../../../lib/software/profile-requirements.nix { inherit pkgs; }).commonTools
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ "procps" ]
    ++ [
      "gnupg"
      "pinentry"
    ]
  ) (_: { });
}
