import ../../../software/consumer.nix {
  scope = "home";
  id = "home-nh";
  software = "nh";
  installedScopes = [ "home" ];
  enableOptions = [
    [
      "programs"
      "nh"
      "enable"
    ]
  ];
  packageOption = [
    "programs"
    "nh"
    "package"
  ];
}
