{
  platform = "darwin";
  packageManager = "homebrew";
  system = "aarch64-darwin";
  systemConfig = ./system.nix;
  homeConfig = ./home.nix;
}
