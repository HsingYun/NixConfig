{
  config,
  lib,
  pkgs,
  user,
  ...
}:
let
  home = config.home-manager.users.${user.username};
  cfg = home.software;
in
{
  environment.systemPackages = cfg.plan.installations.nix.systemPackages;
  environment.etc = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    "opt/chrome/policies/managed/nixconfig-extensions.json" =
      lib.mkIf (home.software.chromeExtensionPolicy != { })
        {
          text = builtins.toJSON home.software.chromeExtensionPolicy;
        };
  };
  _module.args.software = cfg.resolved;
}
