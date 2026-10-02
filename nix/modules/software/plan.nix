{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.software;
  selection = import ../../lib/software/resolve.nix { inherit lib; } {
    inherit (cfg)
      requirements
      packageManager
      platform
      nativePrefix
      providerOverrides
      packageOverrides
      packageDefaults
      ;
    inherit pkgs;
    catalog = import ../../lib/software/catalog.nix { inherit pkgs; };
  };
  plan = import ../../lib/software/materialize.nix { inherit lib; } {
    inherit selection;
    inherit (cfg) runtimeArtifacts;
  };
in
{
  imports = [ ./options.nix ];
  config = {
    software.plan = if cfg.externalPlan == null then plan else cfg.externalPlan;
    software.resolved = cfg.plan.resolved;
    _module.args.software = cfg.resolved;
  };
}
