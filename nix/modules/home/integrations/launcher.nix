{
  config,
  lib,
  ...
}:

{
  imports = [ ../shared/launcher.nix ];

  desktop.launcher = {
    hiddenEntries = lib.mkDefault config.features.desktop.launcher.hiddenEntries;
  };
}
