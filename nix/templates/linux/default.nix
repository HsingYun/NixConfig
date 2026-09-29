{
  platform = "linux";
  # Choose "pacman" on Arch Linux, or "nix" for a Nix-only user environment.
  packageManager = "nix";
  system = "x86_64-linux";
  homeConfig = ./home.nix;
}
