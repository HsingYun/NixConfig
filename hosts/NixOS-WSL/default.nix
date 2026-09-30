{ profile, ... }:
{
  platform = "nixos-wsl";
  packageManager = "nix";
  system = "x86_64-linux";
  features = profile.cli // {
    smartcard = profile.cli.smartcard // {
      allowBackgroundAccess = true;
    };
  };
  systemConfig = ./system.nix;
  homeConfig = ./home.nix;
}
