{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop.launcher;
  rules = pkgs.writeText "launcher-rules.json" (
    builtins.toJSON {
      inherit (cfg) hiddenEntries;
      nativeRoots = [ (toString cfg.entries) ] ++ cfg.nativeRoots;
    }
  );
in
{
  desktop.launcher.nativeRoots = lib.mkIf config.features.desktop.launcher.enable [
    "/usr/local"
    "/usr"
  ];
  # Keep removal active after the feature is disabled.
  home.activation.launcherOverrides =
    lib.hm.dag.entryAfter [ "linkGeneration" "installNativePackages" "removeReplacedNativePackages" ]
      ''
        run ${lib.getExe pkgs.python3} ${../../../assets/helpers}/arch/launcher.py ${rules} \
          ${lib.escapeShellArg config.xdg.dataHome} ${lib.escapeShellArg config.xdg.stateHome} \
          ${pkgs.desktop-file-utils}/bin/desktop-file-install
      '';
}
