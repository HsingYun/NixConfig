{ lib, pkgs, ... }:
{
  software.requirements = lib.genAttrs (
    builtins.attrNames (import ../../../lib/software/profiles.nix { inherit pkgs; }).commonTools
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ "procps" ]
    ++ [
      "gnupg"
      "pinentry"
    ]
  ) (_: { });
}
