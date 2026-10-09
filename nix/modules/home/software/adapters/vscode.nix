import ../../../software/consumer.nix {
  scope = "home";
  id = "home-vscode";
  software = "vscode";
  installedScopes = [ "home" ];
  enableOptions = [
    [
      "programs"
      "vscode"
      "enable"
    ]
  ];
  packageOption = [
    "programs"
    "vscode"
    "package"
  ];
}
