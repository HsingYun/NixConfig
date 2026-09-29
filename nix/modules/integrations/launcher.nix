{
  config,
  lib,
  osConfig ? { },
  ...
}:

{
  imports = [ ../home/shared/launcher.nix ];

  desktop.launcher = {
    hiddenEntries = lib.mkDefault config.features.desktop.launcher.hiddenEntries;
    packageRoots = lib.mkIf (config.software.platform == "nixos") (
      lib.mkAfter [ osConfig.system.path ]
    );
    nativeRoots = lib.mkIf (config.software.platform == "arch") [
      "/usr/local"
      "/usr"
    ];
  };
}
