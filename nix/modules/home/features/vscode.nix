{
  config,
  lib,
  ...
}:
{
  software = {
    requirements = {
      vscode.scopes = [ ];
      maple-mono = { };
    };
  };
  programs.vscode = {
    enable = lib.mkDefault true;

    profiles.default = {
      mutableUserSettings = true;
      userSettings = config.features.vscode.settings;
    };
  };
}
