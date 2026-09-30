{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.features.chrome.enable) {
    software = {
      requirements.chrome.scopes = [ ];
    };
    programs.google-chrome = {
      enable = lib.mkDefault true;

      extensions = config.features.chrome.extensions;
    };
  };
}
