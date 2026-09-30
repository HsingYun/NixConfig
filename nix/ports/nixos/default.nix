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
  upstreamNixos = true;
  output = "nixosConfigurations";
  builder = "nixos";
  packageManager = "nix";
  defaultSystem = "x86_64-linux";
  systemPolicy = ./integrations;
  systemModules = [ ./system/default.nix ];
  homeModules = [
    ./home/keyring.nix
    ./home/launcher.nix
    ./home/capabilities/dms.nix
  ];
  features = {
    network.systemModules = [ ./system/network.nix ];
    plymouth.systemModules = [ ./system/plymouth.nix ];
    nixLd.systemModules = [ ./system/nix-ld.nix ];
    wallpaper.systemModules = [ ./system/greeter-wallpaper.nix ];
    launcher.homeModules = [ ./home/launcher-feature.nix ];
    printing.systemModules = [ ./system/printing.nix ];
    chinese = {
      systemModules = [ ./system/chinese.nix ];
      homeModules = [ ./home/chinese.nix ];
    };
    dms = {
      homeModules = [ ./home/dms.nix ];
      systemModules = [ ./system/dms.nix ];
    };
    niri = {
      homeModules = [ ./home/niri.nix ];
      systemModules = [ ./system/niri.nix ];
    };
    gnome = {
      homeModules = [ ./home/gnome.nix ];
      systemModules = [ ./system/gnome.nix ];
    };
  };
  integrations = {
    gpg-smartcard.homeModules = [ ./home/smartcard.nix ];
    niri-dms = {
      homeModules = [ ./home/niri-dms.nix ];
    };
    gnome-chinese = {
      homeModules = [ ./home/gnome-chinese.nix ];
    };
  };
}
