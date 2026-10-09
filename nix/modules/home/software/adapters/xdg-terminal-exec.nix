import ../../../software/consumer.nix {
  scope = "home";
  id = "home-xdg-terminal-exec";
  software = "xdg-terminal-exec";
  installedScopes = [ "home" ];
  enableOptions = [
    [
      "xdg"
      "terminal-exec"
      "enable"
    ]
  ];
  packageOption = [
    "xdg"
    "terminal-exec"
    "package"
  ];
}
