{ lib, software, ... }:
{
  options.desktop.applications.browser = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule {
        config = {
          command = lib.mkDefault [ (software.chrome.command "google-chrome-stable") ];
          desktopId = lib.mkDefault "google-chrome.desktop";
        };
      }
    );
  };
  config.desktop.applications.browser = lib.mkDefault { };
}
