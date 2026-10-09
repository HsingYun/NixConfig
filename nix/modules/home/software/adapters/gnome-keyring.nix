import ../../../software/consumer.nix {
  scope = "home";
  id = "home-gnome-keyring";
  software = "gnome-keyring";
  enableOptions = [
    [
      "services"
      "gnome-keyring"
      "enable"
    ]
  ];
  packageOption = [
    "services"
    "gnome-keyring"
    "package"
  ];
}
