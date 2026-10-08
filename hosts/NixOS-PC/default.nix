{ lib, profile, ... }:
{
  platform = "nixos";
  packageManager = "nix";
  system = "x86_64-linux";
  stateVersion = {
    home = "26.05";
    system = "26.11";
  };
  timeZone = "Asia/Shanghai";
  features = lib.recursiveUpdate profile.linuxDesktop {
    desktop.autostart = {
      enable = true;
      entries.terminal.application = "terminal";
    };
  };
  hardwareConfig = ./hardware.nix;
}
