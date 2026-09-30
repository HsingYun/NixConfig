{
  config,
  lib,
  pkgs,
  software,
  ...
}:
{
  config = lib.mkIf (pkgs.stdenv.hostPlatform.isDarwin && config.features.chrome.enable) {
    software = {
      requirements.chrome.installNix = false;
      bindings.chrome = {
        enableOption = [
          "programs"
          "google-chrome"
          "enable"
        ];
        packageOption = [
          "programs"
          "google-chrome"
          "package"
        ];
        runtimePackageOption = [
          "programs"
          "google-chrome"
          "finalPackage"
        ];
      };
    };
    programs.google-chrome = {
      enable = lib.mkDefault true;
      package = lib.mkDefault software.chrome.package;
      extensions = config.features.chrome.extensions;
    };
  };
}
