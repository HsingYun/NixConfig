{ inputs, hosts }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  ports = (import ../../lib/platforms).definitions;
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  make =
    platform: features: featureConfig:
    let
      bootstrap = import ../fixtures/platform.nix { port = ports.${platform}; };
    in
    (mkHost "HostInterface" {
      inherit platform featureConfig;
      inherit (bootstrap) hardwareConfig;
      features = allOff // features;
      stateVersion = {
        home = "26.05";
      }
      // lib.optionalAttrs (platform != "arch") {
        system = if platform == "darwin" then 6 else "26.11";
      };
      timeZone = if platform == "arch" then null else "Asia/Shanghai";
    }).views;
  gnome = make "nixos" { gnome = true; } {
    desktop.gnome.textEditor = {
      auto-indent = true;
      tab-width = 8;
    };
    desktop.gnome.settings."org/gnome/TextEditor".wrap-text = true;
  };
  mac = make "darwin" { macos = true; } {
    desktop.macos.settings.finder.ShowPathbar = true;
  };
  macOff = make "darwin" { } { desktop.macos.settings.finder.ShowPathbar = true; };
  wsl = make "nixos-wsl" {
    usbip = true;
    gpg = true;
  } { gpg.pinentry = "curses"; };
  wslOff = make "nixos-wsl" { } { gpg.pinentry = "curses"; };
  rotate =
    make "nixos"
      {
        gnome = true;
        screenRotate = true;
      }
      {
        desktop.screenRotate.settings.orientation-offset = 2;
      };
  rotateOff = make "nixos" { gnome = true; } {
    desktop.screenRotate.settings.orientation-offset = 2;
  };
  home = name: hosts.${name}.views.home;
  system = name: hosts.${name}.views.system;
  expectedState = {
    ArchLinux = null;
    Darwin = 6;
    NixOS-PC = "26.11";
    NixOS-Pad = "26.11";
    NixOS-WSL = "26.11";
  };
  # System features consume host input without a Home Manager-shaped schema.
  systemOnly = lib.evalModules {
    modules = [
      ../../modules/shared/features.nix
      ../../contracts/system/services/mihomo.nix
      ../../modules/system/features/mihomo.nix
      {
        options.assertions = lib.mkOption {
          type = lib.types.listOf lib.types.raw;
          default = [ ];
        };
        config.features.mihomo = {
          configFile = "/etc/mihomo/config.yaml";
          tunMode = false;
        };
      }
    ];
  };
  hostDefinitions = lib.mapAttrs (
    _: path: import ../../lib/hosts/load.nix { inherit lib; } (import path)
  ) (import ../../../hosts);
in
assert systemOnly.config.services.mihomo.enable && !systemOnly.config.services.mihomo.tunMode;
assert !(systemOnly.options ? home-manager);
assert lib.all (a: a.assertion) systemOnly.config.assertions;
assert lib.all (
  name: builtins.toJSON (system name).features == builtins.toJSON (home name).features
) (builtins.attrNames hosts);
assert lib.all (h: !(h ? homeConfig) && !(h ? systemConfig)) (builtins.attrValues hostDefinitions);
assert lib.all (
  name:
  (home name).home.stateVersion == "26.05"
  && ((system name).system.stateVersion or null) == expectedState.${name}
) (builtins.attrNames expectedState);
assert lib.all (cfg: lib.all (a: a.assertion) (cfg.home.assertions ++ cfg.system.assertions)) [
  gnome
  mac
  macOff
  wsl
  wslOff
  rotate
  rotateOff
];
assert gnome.system.time.timeZone == "Asia/Shanghai";
assert mac.system.time.timeZone == "Asia/Shanghai";
assert mac.system.system.defaults.finder.ShowPathbar;
assert macOff.system.system.defaults.finder.ShowPathbar == null;
assert wsl.system.wsl.usbip.enable && !wslOff.system.wsl.usbip.enable;
assert lib.getName wsl.home.services.gpg-agent.pinentry.package == "pinentry-curses";
assert !(wslOff.home.software.resolved ? pinentry);
assert
  rotate.home.dconf.settings."org/gnome/shell/extensions/screen-rotate".orientation-offset == 2;
assert !(rotateOff.home.dconf.settings ? "org/gnome/shell/extensions/screen-rotate");
assert gnome.home.dconf.settings."org/gnome/TextEditor".auto-indent;
assert gnome.home.dconf.settings."org/gnome/TextEditor".tab-width.type == "u";
assert gnome.home.dconf.settings."org/gnome/TextEditor".tab-width.value == 8;
assert gnome.home.dconf.settings."org/gnome/TextEditor".wrap-text;
assert
  builtins.toJSON (home "NixOS-Pad").dconf.settings."org/gnome/TextEditor" == builtins.toJSON {
    auto-indent = false;
    restore-session = false;
    show-line-numbers = true;
    spellcheck = false;
    tab-width = inputs.home-manager.lib.hm.gvariant.mkUint32 32;
    wrap-text = false;
  };
{
  singleHostEntry = true;
  compatibilityVersionsPreserved = true;
  nativeFeatureSettings = true;
  disabledFeaturesLeaveNoSettings = true;
  editorDefaultsOverridable = true;
}
