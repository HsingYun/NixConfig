{ lib }:
definition:
let
  host = lib.toFunction definition;
  args = {
    inherit lib;
    profile = import ./profiles.nix;
  };
in
host (builtins.intersectAttrs (lib.functionArgs host) args)
