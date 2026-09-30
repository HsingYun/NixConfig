# A static adapter declaration produces an ordinary Nix module. Keeping option
# paths static avoids deriving the module tree from its own configuration.
{
  id,
  software,
  packageOption,
  enableOptions ? [ ],
  runtimePackageOption ? null,
  installedScopes ? [ ],
  requestWhenEnabled ? false,
}:
{
  config,
  lib,
  ...
}:
let
  cfg = config.software;
  enabled = lib.all (path: lib.getAttrFromPath path config) enableOptions;
  managed = cfg.resolved ? ${software};
  active = managed && enabled;
  selected = cfg.resolved.${software}.package;
  configured = lib.getAttrFromPath packageOption config;
  runtime = lib.getAttrFromPath (
    if runtimePackageOption == null then packageOption else runtimePackageOption
  ) config;
  samePackage =
    a: b: if a == null || b == null then a == null && b == null else toString a == toString b;
in
{
  config = lib.mkMerge [
    {
      software = {
        consumers.${id} = {
          inherit
            software
            packageOption
            enableOptions
            runtimePackageOption
            installedScopes
            requestWhenEnabled
            ;
        };
        requirements.${software} = lib.mkIf (requestWhenEnabled && enabled) { scopes = [ ]; };
        runtimeArtifacts.${id} = lib.mkIf (active && runtime != null) {
          inherit software;
          package = runtime;
          scopes = installedScopes;
        };
      };
      assertions = lib.optional active {
        assertion = samePackage selected configured;
        message = "Software consumer '${id}': ${lib.concatStringsSep "." packageOption} bypasses the selected package. Use software.packageOverrides.${software} instead.";
      };
    }
    (lib.mkIf active (lib.setAttrByPath packageOption (lib.mkDefault selected)))
  ];
}
