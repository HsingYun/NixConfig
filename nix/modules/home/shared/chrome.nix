{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.chrome;
  extensions = if cfg.enable then cfg.extensions else [ ];
  updateUrl = "https://clients2.google.com/service/update2/crx";

in
{
  options.software.chromeExtensionPolicy = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    internal = true;
    description = "System policy consumed by the NixOS and Arch adapters.";
  };

  config = {
    software.chromeExtensionPolicy = lib.optionalAttrs (extensions != [ ]) {
      ExtensionSettings = lib.genAttrs extensions (_: {
        installation_mode = "normal_installed";
        update_url = updateUrl;
      });
    };

    # macOS supports external extensions in the user's Chrome directory.
    home.file = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
      lib.listToAttrs (
        map (id: {
          name = "Library/Application Support/Google/Chrome/External Extensions/${id}.json";
          value.text = builtins.toJSON { external_update_url = updateUrl; };
        }) (lib.unique extensions)
      )
    );
  };
}
