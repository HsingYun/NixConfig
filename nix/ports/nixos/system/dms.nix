{
  lib,
  ...
}:

{
  imports = [
    ../../../modules/system/features/dms.nix
    ./desktop.nix
  ];
  programs = {
    dms-shell = {
      systemd = {
        target = lib.mkDefault "niri.service";
      };
    };
  };

  # This feature pairs the greeter with Niri; direct upstream configurations
  # retain the upstream compositor interface and can select another compositor.
  services.displayManager.dms-greeter.compositor.name = lib.mkDefault "niri";
  security.pam.services.dankshell = { };
}
