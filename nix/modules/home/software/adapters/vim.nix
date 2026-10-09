import ../../../software/consumer.nix {
  scope = "home";
  id = "home-vim";
  software = "vim";
  installedScopes = [ "home" ];
  enableOptions = [
    [
      "programs"
      "vim"
      "enable"
    ]
  ];
  packageOption = [
    "programs"
    "vim"
    "packageConfigurable"
  ];
  runtimePackageOption = [
    "programs"
    "vim"
    "package"
  ];
}
