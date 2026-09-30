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
    runtimeArtifacts = home.software.runtimeArtifacts;
    migration.removeReplaced = home.software.migration.removeReplaced;
  };
  assertions = import ../../lib/software/check-installations.nix { inherit lib; } {
    scope = "system";
    packages = config.environment.systemPackages;
    inherit (config.software) plan runtimeArtifacts;
  };
  environment.systemPackages = config.software.plan.installations.nix.systemPackages;
}
