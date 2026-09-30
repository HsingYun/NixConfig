{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  ports = (import ../../lib/platforms).definitions;
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  configuration =
    platform:
    let
      bootstrap = import ../fixtures/platform.nix { port = ports.${platform}; };
    in
    (mkHost "NoctaliaConfig" {
      inherit platform;
      inherit (bootstrap) hardwareConfig;
      features = allOff // {
        niri = true;
        noctalia = true;
        wallpaper = true;
      };
      featureConfig.desktop = {
        noctalia.settings.theme.mode = "dark";
        wallpaper = {
          image = ../../assets/desktop.png;
          lockImage = ../../assets/background.png;
        };
      };
      systemConfig.imports = [ bootstrap.systemConfig ];
      homeConfig.home.stateVersion = "26.05";
    }).views.home;
  homes = map configuration [
    "nixos"
    "arch"
  ];
in
pkgs.runCommand "noctalia-configuration-check"
  {
    nativeBuildInputs = [
      pkgs.noctalia
      pkgs.niri
    ];
  }
  (
    lib.concatMapStringsSep "\n" (home: ''
      noctalia config validate ${home.xdg.configFile."noctalia/config.toml".source}
      niri validate --config ${home.xdg.configFile."niri/config.kdl".source}
    '') homes
    + ''
      touch "$out"
    ''
  )
