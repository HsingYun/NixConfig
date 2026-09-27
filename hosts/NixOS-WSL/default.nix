{
  platform = "nixos-wsl";
  system = "x86_64-linux";
  systemConfig = ./system.nix;
  homeConfig = ./home.nix;
}
