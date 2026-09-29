{ config, lib, ... }:
let
  plan = config.software.plan.installations.pacman;
in
{
  home.activation.installNativePackages = lib.mkIf (plan.packages != [ ] || plan.aur != [ ]) (
    lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] (
      import ../../../lib/software/pacman-activation.nix { inherit lib; } plan
    )
  );
}
