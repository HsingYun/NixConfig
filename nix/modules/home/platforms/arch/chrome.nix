{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Remains imported when Chrome is disabled so owned policy can be removed.
  home.activation.installChromePolicy = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    import ../../../../assets/helpers/owned-root-file.nix { inherit lib pkgs; } {
      owner = config.home.username;
      active = config.software.chromeExtensionPolicy != { };
      text = builtins.toJSON config.software.chromeExtensionPolicy;
      destination = "/etc/opt/chrome/policies/managed/nixconfig-extensions.json";
    }
  );
}
