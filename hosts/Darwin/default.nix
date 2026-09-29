{
  platform = "darwin";
  system = "aarch64-darwin";
  features.ghostty = true;
  systemConfig = ./system.nix;
  homeConfig = ./home.nix;
}
