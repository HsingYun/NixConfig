{
  config,
  software,
  lib,
  ...
}:

{
  imports = [ ../shared/desktop.nix ];
  programs = {
    niri.enable = lib.mkDefault true;
    dms-shell = {
      package = lib.mkDefault software.dms.package;
      enable = lib.mkDefault true;
      systemd = {
        enable = lib.mkDefault true;
        target = lib.mkDefault "niri.service";
      };
    };
  };
  assertions = [
    {
      assertion = toString config.programs.dms-shell.package == toString software.dms.package;
      message = "Software: programs.dms-shell.package must follow software.packageOverrides.dms in the user's Home Manager configuration.";
    }
  ];
  security.pam.services.dankshell = { };
}
