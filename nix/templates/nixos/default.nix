{
  platform = "nixos";
  system = "x86_64-linux";
  hardwareConfig = ./hardware-configuration.nix;
  systemConfig = ./system.nix;
  homeConfig = ./home.nix;
}
