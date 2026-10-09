# Shared adapter for the DMS capability supplied by either upstream or a port.
import ../../../software/consumer.nix {
  scope = "home";
  id = "home-dms";
  software = "dms";
  installedScopes = [ "home" ];
  enableOptions = [
    [
      "programs"
      "dank-material-shell"
      "enable"
    ]
  ];
  packageOption = [
    "programs"
    "dank-material-shell"
    "package"
  ];
}
