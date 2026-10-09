import ../../../software/consumer.nix {
  scope = "home";
  id = "home-chrome";
  software = "chrome";
  installedScopes = [ "home" ];
  enableOptions = [
    [
      "programs"
      "google-chrome"
      "enable"
    ]
  ];
  packageOption = [
    "programs"
    "google-chrome"
    "package"
  ];
  runtimePackageOption = [
    "programs"
    "google-chrome"
    "finalPackage"
  ];
}
