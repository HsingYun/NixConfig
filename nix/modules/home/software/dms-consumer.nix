# Shared adapter for the DMS capability supplied by either upstream or a port.
import ../../software/consumer.nix {
  id = "home-dms";
  software = "dms";
  requestWhenEnabled = true;
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
