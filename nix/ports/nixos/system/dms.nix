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
    dux-shell = {
      systemd = {
        target = lib.mkDefault "niri.service";
      };
    };
  };

  # This feature pairs the greeter with Niri; direct upstream configurations
  # retain the upstream compositor interface and can select another compositor.
  services.displayManager.dux-greeter.compositor.name = lib.mkDefault "niri";
  security.pam.services.dankshell = { };
}
