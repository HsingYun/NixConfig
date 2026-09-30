{
  config,
  lib,
  user,
  ...
}:
let
  extensions = config.home-manager.users.${user.username}.features.chrome.extensions;
in
{
  # This upstream module manages policies, not the browser package.
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
