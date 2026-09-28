{ lib, osConfig, ... }:

{
  imports = [ ../home/shared/launcher.nix ];

  desktop.launcher.packageRoots = lib.mkAfter [ osConfig.system.path ];
}
