{
  config,
  user,
  ...
}:
let
  home = config.home-manager.users.${user.username};
  cfg = home.software;
in
{
  environment.systemPackages = cfg.plan.installations.nix.systemPackages;
  _module.args.software = cfg.resolved;
}
