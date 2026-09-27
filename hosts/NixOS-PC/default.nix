{
  platform = "nixos";
  system = "x86_64-linux";
  features = {
    devel = true;
    chinese = true;
    niri = true;
    dms = true;
    ghostty = true;
    mpv = true;
  };
  hardwareConfig = ./harware.nix;
  systemConfig = ./system.nix;
  homeConfig = ./home.nix;
}
