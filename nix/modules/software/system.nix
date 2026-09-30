{
  config,
  lib,
  user,
  ...
}:
let
  home = config.home-manager.users.${user.username};
in
{
  imports = [ ./plan.nix ];
  software = {
    requirements = home.software.requirements;
    providerOverrides = home.software.providerOverrides;
    packageOverrides = home.software.packageOverrides;
    runtimePackages = home.software.runtimePackages;
    migration.removeReplaced = home.software.migration.removeReplaced;
  };
  environment.systemPackages = config.software.plan.installations.nix.systemPackages;
}
