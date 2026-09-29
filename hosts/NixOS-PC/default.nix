let
  profile = import ../../nix/lib/hosts/profiles.nix;
in
{
  platform = "nixos";
  packageManager = "nix";
  system = "x86_64-linux";
  features = profile.linuxDesktop;
  preferences = {
    desktop = "niri";
    loginManager = "greetd";
  };
  hardwareConfig = ./hardware.nix;
  systemConfig = ./system.nix;
  homeConfig = ./home.nix;
}
