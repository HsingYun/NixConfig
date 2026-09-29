{
  platform = "nixos";
  system = "x86_64-linux";
  features = {
    devel = true;
    chinese = true;
    gnome = true;
    ghostty = true;
    mpv = true;
  };
  hardwareConfig = ./hardware.nix;
  systemConfig = ./system.nix;
  homeConfig = ./home.nix;
}
