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
    ./home/launcher.nix
    ./home/upstream.nix
  ];
  features = {
    printing.systemModules = [ ./system/printing.nix ];
    chinese = {
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
    niri-dms = {
      homeModules = [ ./home/niri-dms.nix ];
    };
    gnome-chinese = {
      homeModules = [ ./home/gnome-chinese.nix ];
    };
  };
}
