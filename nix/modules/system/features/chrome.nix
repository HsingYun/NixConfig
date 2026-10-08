{
  config,
  lib,
  ...
}:
let
  extensions = config.features.chrome.extensions;
in
{
  # This upstream module manages policies, not the browser package.
  software.requirements.chrome = { };
  programs.chromium = {
    enable = lib.mkDefault true;
    extraOpts = lib.optionalAttrs (extensions != [ ]) {
      ExtensionSettings = lib.genAttrs extensions (_: {
        installation_mode = "normal_installed";
        update_url = "https://clients2.google.com/service/update2/crx";
      });
    };
  };
}
