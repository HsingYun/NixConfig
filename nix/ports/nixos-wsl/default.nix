{
  contracts = [
    "home.gpg"
    "system.printing"
    "system.avahi"
    "system.firmware"
    "system.smartcard"
    "system.chrome"
  ];
  packageProviders = [ "nix" ];
  capabilities = [ ];
  managesSystem = true;
  requiresHardwareConfig = false;
  family = "linux";
  upstreamNixos = true;
  output = "nixosConfigurations";
  builder = "nixos";
  packageManager = "nix";
  defaultSystem = "x86_64-linux";
  systemPolicy = ../nixos/integrations;
  systemModules = [ ./system/default.nix ];
  homeModules = [
    ../nixos/home/capabilities/launcher.nix
    ../nixos/home/features/gnome-keyring.nix
  ];
  features.nixLd.systemModules = [ ../nixos/system/nix-ld.nix ];
  features.usbip.systemModules = [ ./system/usbip.nix ];
  integrations.gpg-smartcard.homeModules = [ ../nixos/home/integrations/gpg-smartcard.nix ];
}
