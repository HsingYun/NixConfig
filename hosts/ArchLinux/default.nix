{ profile, ... }:
{
  platform = "arch";
  packageManager = "pacman";
  system = "x86_64-linux";
  features = profile.linuxDesktop;
  homeConfig = ./home.nix;
}
