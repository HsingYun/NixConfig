{ config, user, ... }:
let
  cfg = config.home-manager.users.${user.username}.software;
in
{
  environment.systemPackages = cfg.plan.installations.nix.systemPackages;
  _module.args.software = cfg.resolved;
}
