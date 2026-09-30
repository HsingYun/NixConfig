{
  contracts = [
    "home.gpg"
    "system.printing"
    "system.smartcard"
    "system.chrome"
  ];
  managesSystem = true;
  family = "linux";
  desktop = false;
  upstreamNixos = true;
  output = "nixosConfigurations";
  builder = "nixos";
  packageManager = "nix";
  defaultSystem = "x86_64-linux";
  systemPolicy = ../nixos/integrations;
  systemModules = [ ./system/default.nix ];
  homeModules = [
    ../nixos/home/launcher.nix
    ../nixos/home/keyring.nix
  ];
  features.nixLd.systemModules = [ ../nixos/system/nix-ld.nix ];
  integrations.gpg-smartcard.homeModules = [ ../nixos/home/smartcard.nix ];
}
