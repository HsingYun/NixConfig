{
  features = (import ../../nix/lib/hosts/profiles.nix).cli // {
    smartcard = {
      enable = true;
      allowBackgroundAccess = true;
    };
  };
  platform = "nixos-wsl";
  system = "x86_64-linux";
  systemConfig = ./system.nix;
  homeConfig = ./home.nix;
}
