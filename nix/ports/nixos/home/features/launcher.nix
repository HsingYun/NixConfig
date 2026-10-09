{ lib, osConfig, ... }: {
  desktop.launcher.packageRoots = lib.mkAfter [ osConfig.system.path ];
}
