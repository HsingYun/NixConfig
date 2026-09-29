{ config, lib, ... }:
let
  cfg = config.software;
  entries = lib.mapAttrsToList (name: binding: {
    inherit name binding;
    active = binding.enableOption == null || lib.getAttrFromPath binding.enableOption config;
    selected = cfg.resolved.${name}.package;
    configured = lib.getAttrFromPath binding.packageOption config;
  }) cfg.bindings;
  samePackage =
    a: b: if a == null || b == null then a == null && b == null else toString a == toString b;
in
{
  options.software.bindings = lib.mkOption {
    default = { };
    description = "Feature adapters binding an upstream package option to a software identity.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          packageOption = lib.mkOption { type = lib.types.listOf lib.types.str; };
          enableOption = lib.mkOption {
            type = lib.types.nullOr (lib.types.listOf lib.types.str);
            default = null;
            description = "Upstream enable option; inactive modules do not expose a runtime package or participate in binding validation.";
          };
          runtimePackageOption = lib.mkOption {
            type = lib.types.nullOr (lib.types.listOf lib.types.str);
            default = null;
            description = "Final upstream wrapper used at runtime, if different from the input package.";
          };
        };
      }
    );
  };
  config.assertions = map (entry: {
    assertion = !entry.active || samePackage entry.selected entry.configured;
    message = "Software: ${lib.concatStringsSep "." entry.binding.packageOption} bypasses the selected package. Use software.packageOverrides.${entry.name} instead.";
  }) entries;
}
