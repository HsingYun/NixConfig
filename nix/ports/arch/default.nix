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
  packageProviders = [
    "nix"
    "pacman"
  ];
  capabilities = [ "efi" ];
  managesSystem = true;
  requiresHardwareConfig = false;
  family = "linux";
  upstreamNixos = false;
  output = "homeConfigurations";
  builder = "native";
  packageManager = "pacman";
  defaultSystem = "x86_64-linux";
  systemModules = [
    ./system
  ];
  homeModules = [ ./home ];
  features = {
    chinese.homeModules = [ ./home/features/chinese.nix ];
    noctalia.systemModules = [ ../../modules/system/features/noctalia.nix ];
    dms = {
      systemModules = [ ../../modules/system/features/dms.nix ];
    };
    niri = {
      systemModules = [ ../../modules/system/features/niri.nix ];
    };
    gnome = {
      homeModules = [ ./home/features/gnome.nix ];
      systemModules = [ ../../modules/system/features/gnome.nix ];
    };
  };
  integrations = {
    niri-dms = {
      homeModules = [ ./home/integrations/niri-dms.nix ];
    };
    gnome-chinese = {
      homeModules = [ ./home/integrations/gnome-chinese.nix ];
    };
  };
}
