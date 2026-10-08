{ lib, profile, ... }:
{
  platform = "nixos";
  packageManager = "nix";
  system = "x86_64-linux";
  features = lib.recursiveUpdate profile.linuxDesktop {
    desktop.autostart.enable = true;
  };
  hardwareConfig = ./hardware.nix;
  systemConfig = ./system.nix;
  homeConfig = ./home.nix;
}
