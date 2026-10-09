import ../../../software/consumer.nix {
  scope = "home";
  id = "home-ghostty";
  software = "ghostty";
  installedScopes = [ "home" ];
  enableOptions = [
    [
      "programs"
      "ghostty"
      "enable"
    ]
  ];
  packageOption = [
    "programs"
    "ghostty"
    "package"
  ];
}
