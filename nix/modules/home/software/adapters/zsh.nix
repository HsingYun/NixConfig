import ../../../software/consumer.nix {
  scope = "home";
  id = "home-zsh";
  software = "zsh";
  installedScopes = [ "home" ];
  enableOptions = [
    [
      "programs"
      "zsh"
      "enable"
    ]
  ];
  packageOption = [
    "programs"
    "zsh"
    "package"
  ];
}
