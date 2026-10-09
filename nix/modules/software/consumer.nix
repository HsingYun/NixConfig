# A static adapter declaration produces an ordinary Nix module. Keeping option
# paths static avoids deriving the module tree from its own configuration.
# Enabled application/service consumers contribute their own demand. Resource
# bindings (such as a chosen icon theme) only follow an existing requirement.
{
  id,
  scope,
  software,
  packageOption,
  enableOptions ? [ ],
  runtimePackageOption ? null,
  installedScopes ? [ ],
  requestWhenEnabled ? true,
  imports ? [ ],
  capabilities ? [ ],
  demands ? { },
  when ? (_: true),
}:
{
  config,
  options,
  lib,
  ...
}:
let
  cfg = config.software;
  enabled = lib.all (path: lib.getAttrFromPath path config) enableOptions && when config;
  managed = cfg.resolved ? ${software};
  active = managed && enabled;
  # Subfeatures can need a store executable even when the package option is
  # nullable. Conditions read intent, never the selected package or provider.
  evaluatedDemands = lib.mapAttrs (_: demand: {
    enabled = enabled && demand.when config;
    inherit (demand) capabilities;
  }) demands;
  activeDemands = lib.filterAttrs (_: demand: demand.enabled) evaluatedDemands;
  # Several consumers can use one package option (GPG and its agent). Bind it
  # once per module scope, including options whose upstream type is unique.
  bindingOwner = builtins.head (
    builtins.attrNames (
      lib.filterAttrs (
        _: consumer: consumer.scope == scope && consumer.packageOption == packageOption && consumer.enabled
      ) cfg.consumers
    )
  );
  selected = cfg.resolved.${software}.package;
  configured = lib.getAttrFromPath packageOption config;
  runtime = lib.getAttrFromPath (
    if runtimePackageOption == null then packageOption else runtimePackageOption
  ) config;
  samePackage =
    a: b: if a == null || b == null then a == null && b == null else toString a == toString b;
in
{
  inherit imports;
  config = lib.mkMerge [
    {
      software = {
        consumers.${id} = {
          inherit id scope enabled;
          demands = evaluatedDemands;
          requiredBy = [ id ] ++ map (name: "${id}.${name}") (builtins.attrNames activeDemands);
          # A non-nullable upstream package option needs a Nix runtime. Native
          # delegation is possible only when that interface supports null.
          capabilities = lib.unique (
            capabilities
            ++ lib.concatMap (demand: demand.capabilities) (builtins.attrValues activeDemands)
            ++ lib.optional (!(lib.getAttrFromPath packageOption options).type.check null) "store-package"
          );
          inherit
            software
            packageOption
            enableOptions
            runtimePackageOption
            installedScopes
            requestWhenEnabled
            ;
        };
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
    (lib.mkIf (active && bindingOwner == id) (lib.setAttrByPath packageOption (lib.mkDefault selected)))
  ];
}
