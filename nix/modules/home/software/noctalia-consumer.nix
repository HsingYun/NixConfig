import ../../software/consumer.nix {
  id = "home-noctalia";
  software = "noctalia";
  installedScopes = [ "home" ];
  requestWhenEnabled = true;
  enableOptions = [
    [
      "programs"
      "noctalia"
      "enable"
    ]
  ];
  packageOption = [
    "programs"
    "noctalia"
    "package"
  ];
}
