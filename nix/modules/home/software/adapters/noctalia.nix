import ../../../software/consumer.nix {
  scope = "home";
  id = "home-noctalia";
  software = "noctalia";
  demands.service = {
    when = config: config.programs.noctalia.systemd.enable;
    capabilities = [ "store-package" ];
  };
  installedScopes = [ "home" ];
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
