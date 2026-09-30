{
  contracts = [
    "home.gpg"
    "home.dms"
    "home.niri"
    "home.input-method"
    "system.printing"
    "system.smartcard"
    "system.chrome"
    "system.desktop"
  ];
  managesSystem = true;
  family = "linux";
  desktop = true;
  upstreamNixos = false;
  output = "homeConfigurations";
  builder = "native";
  packageManager = "pacman";
  defaultSystem = "x86_64-linux";
  systemModules = [
    ./system
    ./system/desktop-policy.nix
  ];
  homeModules = [ ./home ];
  features = {
    dms = {
      systemModules = [ ../../modules/system/features/desktop-session.nix ];
    };
    niri = {
      homeModules = [ ./home/niri.nix ];
      systemModules = [ ../../modules/system/features/desktop-session.nix ];
    };
    gnome = {
      homeModules = [ ./home/gnome.nix ];
      systemModules = [ ../../modules/system/features/desktop-session.nix ];
    };
  };
  integrations = {
    niri-dms = {
      homeModules = [ ./home/niri-dms.nix ];
    };
    gnome-chinese = {
      homeModules = [ ./home/gnome-chinese.nix ];
    };
  };
}
