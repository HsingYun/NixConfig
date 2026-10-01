{
  config,
  lib,
  user,
  ...
}:
let
  cfg = config.home-manager.users.${user.username}.features.mihomo;
in
{
  services.mihomo = {
    enable = lib.mkDefault true;
    configFile = lib.mkDefault cfg.configFile;
    tunMode = lib.mkDefault cfg.tunMode;
  };
  # Private-file policy belongs to this feature. Direct upstream service
  # configuration remains available when the feature is disabled.
  assertions = lib.optional config.services.mihomo.enable {
    assertion =
      builtins.isString config.services.mihomo.configFile
      && lib.hasPrefix "/" config.services.mihomo.configFile
      && !(lib.hasPrefix "${builtins.storeDir}/" config.services.mihomo.configFile)
      && !(lib.hasInfix "\n" config.services.mihomo.configFile);
    message = "Mihomo requires an absolute runtime configFile string outside the Nix store; do not use a Nix path literal for private configuration.";
  };
}
