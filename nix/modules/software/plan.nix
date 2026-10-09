{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.software;
  # Consumer enables describe intent, never provider-derived implementation.
  # Keep their scopes separate until defaults on explicit requirements have been
  # applied: a consumer's empty scopes must not erase a feature's default scope.
  consumers = lib.filter (consumer: consumer.requestWhenEnabled && consumer.enabled) (
    builtins.attrValues cfg.consumers
  );
  consumerRequirements = lib.foldl' (
    requests: consumer:
    requests
    // {
      ${consumer.software} = {
        scopes = [ ];
        capabilities = (requests.${consumer.software}.capabilities or [ ]) ++ consumer.capabilities;
        requiredBy = (requests.${consumer.software}.requiredBy or [ ]) ++ consumer.requiredBy;
      };
    }
  ) { } consumers;
  requirements =
    lib.zipAttrsWith
      (_: requests: {
        capabilities = lib.unique (lib.concatMap (request: request.capabilities or [ ]) requests);
        scopes = lib.unique (lib.concatMap (request: request.scopes or [ ]) requests);
        requiredBy = lib.unique (lib.concatMap (request: request.requiredBy or [ ]) requests);
      })
      [
        cfg.requirements
        consumerRequirements
      ];
  selection =
    import ../../lib/software/resolve.nix
      {
        inherit lib;
        platformProviders = (import ../../lib/platforms).packageProviders;
      }
      {
        inherit (cfg)
          packageManager
          platform
          nativePrefix
          providerOverrides
          packageOverrides
          packageDefaults
          ;
        inherit requirements;
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
