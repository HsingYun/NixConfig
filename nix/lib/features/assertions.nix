{
  lib,
  catalog,
  enabled,
  platform ? "nixos",
}:

let
  activationFor =
    feature:
    catalog.features.${feature}.activationByPlatform.${platform}
      or catalog.features.${feature}.activation;
  rules = lib.concatMap (
    feature:
    map (dependency: {
      inherit feature dependency;
      from = activationFor feature;
      to = activationFor dependency;
    }) (catalog.features.${feature}.requires or [ ])
  ) (lib.filter (feature: enabled.${feature}) (builtins.attrNames catalog.features));
  homeOnly = rule: rule.from.scope == "home" && rule.to.scope == "home";
  check =
    scopes: rule:
    let
      active =
        feature: activation:
        let
          path = lib.concatStringsSep "." activation.option;
          scope = scopes.${activation.scope};
          value = lib.getAttrFromPath activation.option scope;
        in
        assert lib.assertMsg (lib.hasAttrByPath activation.option scope)
          "Feature catalog: features.${feature}.activation references missing ${activation.scope} option '${path}'.";
        assert lib.assertMsg (builtins.isBool value)
          "Feature catalog: features.${feature}.activation option '${path}' must be boolean.";
        value;
      from = active rule.feature rule.from;
      to = active rule.dependency rule.to;
    in
    {
      assertion = builtins.seq from (builtins.seq to (!from || to));
      message = "Feature ${rule.feature} requires ${rule.dependency}: enable the dependency through a feature or systemConfig/homeConfig.";
    };
in
{
  homeModule = { config, ... }: {
    assertions = map (check { home = config; }) (lib.filter homeOnly rules);
  };

  systemModule = { config, user, ... }: {
    assertions = map (check {
      system = config;
      home = config.home-manager.users.${user.username};
    }) (lib.filter (rule: !homeOnly rule) rules);
  };
}
