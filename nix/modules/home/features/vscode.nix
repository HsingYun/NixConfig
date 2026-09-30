{
  config,
  lib,
  software,
  ...
}:
{
  software = {
    requirements.vscode.installNix = false;
    bindings.vscode = {
      enableOption = [
        "programs"
        "vscode"
        "enable"
      ];
      packageOption = [
        "programs"
        "vscode"
        "package"
      ];
    };
  };
  programs.vscode = {
    enable = lib.mkDefault true;
    package = lib.mkDefault software.vscode.package;
    profiles.default = {
      mutableUserSettings = true;
      userSettings = config.features.vscode.settings;
    };
  };
}
