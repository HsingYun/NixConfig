{
  contracts = [
    "system.mihomo"
    "home.gpg"
    "home.dms"
    "home.noctalia"
    "system.noctalia"
    "system.noctalia-greeter"
    "home.niri"
    "home.input-method"
    "system.printing"
    "system.avahi"
    "system.firmware"
    "system.smartcard"
    "system.chrome"
    "system.gnome"
    "system.niri"
    "system.dms"
    "system.session"
    "system.network"
    "system.audio"
    "system.bluetooth"
    "system.power"
    "system.storage"
  ];
  packageProviders = [ "nix" ];
  capabilities = [ "efi" ];
  managesSystem = true;
  requiresHardwareConfig = true;
  family = "linux";
  upstreamNixos = true;
  output = "nixosConfigurations";
  builder = "nixos";
  packageManager = "nix";
  defaultSystem = "x86_64-linux";
  systemPolicy = ./integrations;
  systemModules = [ ./system/default.nix ];
  homeModules = [
    ./home/capabilities/launcher.nix
    ./home/capabilities/niri.nix
    ./home/capabilities/dms.nix
    ../../modules/home/software/adapters/noctalia.nix
  ];
  features = {
    keyring.homeModules = [ ./home/features/gnome-keyring.nix ];
    network.systemModules = [ ./system/network.nix ];
    plymouth.systemModules = [ ./system/plymouth.nix ];
    nixLd.systemModules = [ ./system/nix-ld.nix ];
    wallpaper.systemModules = [ ./system/greeter-wallpaper.nix ];
    launcher.homeModules = [ ./home/features/launcher.nix ];
    printing.systemModules = [ ./system/printing.nix ];
    chinese = {
      systemModules = [ ./system/chinese.nix ];
      homeModules = [ ./home/features/chinese.nix ];
    };
    noctalia.systemModules = [ ./system/noctalia.nix ];
    dms = {
      homeModules = [ ./home/features/dms.nix ];
      systemModules = [ ./system/dms.nix ];
    };
    niri = {
      systemModules = [ ./system/niri.nix ];
    };
    gnome = {
      homeModules = [ ./home/features/gnome.nix ];
      systemModules = [ ./system/gnome.nix ];
    };
  };
  integrations = {
    gpg-smartcard.homeModules = [ ./home/integrations/gpg-smartcard.nix ];
    niri-dms = {
      homeModules = [ ./home/integrations/niri-dms.nix ];
    };
    gnome-chinese = {
      homeModules = [ ./home/integrations/gnome-chinese.nix ];
    };
  };
}
