{
  config,
  lib,
  pkgs,
  ...
}:
let
  extensions = if config.features.chrome.enable then config.features.chrome.extensions else [ ];
  policy = lib.optionalAttrs (extensions != [ ]) {
    ExtensionSettings = lib.genAttrs extensions (_: {
      installation_mode = "normal_installed";
      update_url = "https://clients2.google.com/service/update2/crx";
    });
  };
in
{
  # Remains imported when Chrome is disabled so owned policy can be removed.
  home.activation.installChromePolicy = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    import ../../../../assets/helpers/owned-root-file.nix { inherit lib pkgs; } {
      owner = config.home.username;
      active = policy != { };
      text = builtins.toJSON policy;
      destination = "/etc/opt/chrome/policies/managed/nixconfig-extensions.json";
    }
  );
}
