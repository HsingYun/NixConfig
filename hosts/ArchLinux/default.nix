let
  profile = import ../../nix/lib/hosts/profiles.nix;
in
{
  platform = "arch";
  packageManager = "pacman";
  system = "x86_64-linux";
  features = profile.linuxDesktop;
  preferences = {
    desktop = "niri";
    loginManager = "greetd";
  };
  homeConfig = ./home.nix;
}
