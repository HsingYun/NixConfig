{
  config,
  lib,
  software,
  ...
}:

let
  native = config.software.platform == "arch";
in
{
  software.bindings.dms = {
    enableOption = [
      "programs"
      "dank-material-shell"
      "enable"
    ];
    packageOption = [
      "programs"
      "dank-material-shell"
      "package"
    ];
  };
  imports = [
    ../shared/desktop.nix
  ];

  programs.dank-material-shell = {
    package = lib.mkDefault software.dms.package;
    enable = lib.mkDefault true;

    inherit (config.features.desktop.dms) settings session;
    enableCalendarEvents = lib.mkDefault false;
    # NixOS owns the service; Home Manager owns declarative configuration.
    systemd.enable = lib.mkDefault native;
  };
  software.requirements.dms = {
    capabilities = lib.optionals (!native) [ "store-package" ];
    installNix = native;
  };
}
