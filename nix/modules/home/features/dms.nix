{
  config,
  lib,
  software,
  ...
}:

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
  };
}
