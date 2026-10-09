import ../../../software/consumer.nix {
  scope = "home";
  id = "home-tela";
  software = "tela";
  # Enabling GTK does not select a particular icon theme.
  requestWhenEnabled = false;
  installedScopes = [ "home" ];
  enableOptions = [
    [
      "gtk"
      "enable"
    ]
  ];
  packageOption = [
    "gtk"
    "iconTheme"
    "package"
  ];
}
