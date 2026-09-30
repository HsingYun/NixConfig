{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  ports = (import ../../lib/platforms).definitions;
  catalog = (import ../../lib/features/catalog.nix { inherit lib; }).features;
  allOff = lib.genAttrs (builtins.attrNames catalog) (_: false);
  make =
    platform: change:
    let
      bootstrap = import ../fixtures/platform.nix { port = ports.${platform}; };
    in
    (mkHost "ShellTest" {
      inherit platform;
      inherit (bootstrap) hardwareConfig;
      features =
        (builtins.removeAttrs allOff (change.unspecified or [ ]))
        // {
          niri = true;
        }
        // (change.features or { });
      featureConfig = change.featureConfig or { };
      preferences = change.preferences or { };
      systemConfig.imports = [
        bootstrap.systemConfig
        (change.system or { })
      ];
      homeConfig = {
        imports = [ (change.home or { }) ];
        home.stateVersion = "26.05";
      };
    }).views;
  valid = cfg: lib.all (a: a.assertion) (cfg.system.assertions ++ cfg.home.assertions);
  invalid =
    cfg:
    let
      result = builtins.tryEval (valid cfg);
    in
    !result.success || !result.value;
  running =
    cfg: program:
    cfg.system.programs.${program}.enable && cfg.system.programs.${program}.systemd.enable;
  binds = cfg: builtins.toJSON (cfg.home.wayland.windowManager.niri.settings.binds or { });
  check =
    platform:
    let
      only = make platform { features.noctalia = true; };
      both = make platform {
        features = {
          dms = true;
          noctalia = true;
        };
      };
      selected = make platform {
        features = {
          dms = true;
          noctalia = true;
        };
        featureConfig.desktop.niri.shell = "noctalia";
      };
      cascade =
        shell:
        make platform {
          unspecified = [ shell ];
          featureConfig.desktop.niri.shell = shell;
        };
      neither = make platform { };
      conflict = make platform {
        features = {
          dms = true;
          noctalia = true;
        };
        system.programs.noctalia.systemd.enable = true;
      };
      greeterConflict = make platform {
        features.noctalia = true;
        system.services.displayManager.dms-greeter.enable = true;
      };
      gnome = make platform {
        features = {
          noctalia = true;
          gnome = true;
        };
        preferences.desktop = "gnome";
      };
      crossScope = make platform {
        features.dms = true;
        home.programs.noctalia = {
          enable = true;
          systemd.enable = true;
        };
      };
      direct = make platform {
        system.programs.noctalia = {
          enable = true;
          systemd.enable = true;
        };
      };
    in
    assert valid only && valid both && valid selected && valid neither && valid direct;
    assert invalid conflict && invalid crossScope && invalid greeterConflict;
    assert
      valid gnome
      && gnome.system.services.displayManager.gdm.enable
      && !gnome.system.services.displayManager.noctalia-greeter.enable
      && !gnome.system.services.greetd.enable;
    assert lib.all
      (
        shell:
        let
          cfg = cascade shell;
        in
        valid cfg
        && cfg.home.features.desktop.${shell}.enable
        && running cfg (if shell == "dms" then "dms-shell" else shell)
      )
      [
        "dms"
        "noctalia"
      ];
    assert running only "noctalia" && !(running only "dms-shell");
    assert running both "dms-shell" && !(running both "noctalia");
    assert running selected "noctalia" && !(running selected "dms-shell");
    assert lib.hasInfix "panel-toggle" (binds only) && lib.hasInfix "panel-toggle" (binds selected);
    assert !lib.hasInfix "spotlight" (binds selected) && lib.hasInfix "spotlight" (binds both);
    assert !neither.home.programs.noctalia.enable && !(neither.home.software.resolved ? noctalia);
    assert !selected.system.services.displayManager.dms-greeter.enable;
    assert selected.system.services.displayManager.noctalia-greeter.enable;
    assert both.system.services.displayManager.dms-greeter.enable;
    assert !both.system.services.displayManager.noctalia-greeter.enable;
    assert selected.system.services.displayManager.noctalia-greeter.settings.session.default == "niri";
    assert lib.hasInfix "noctalia-greeter-session"
      selected.system.services.greetd.settings.default_session.command;
    assert platform != "arch" || selected.system.software.resolved.noctalia-greeter.nativeType == "aur";
    assert only.system.programs.noctalia.systemd.target == "niri.service";
    assert
      only.home.software.resolved.noctalia.provider == (if platform == "arch" then "pacman" else "nix");
    assert
      platform != "arch"
      || (
        only.home.programs.noctalia.package == null
        && only.home.systemd.user.services.noctalia.Service.ExecStart == [ "/usr/bin/noctalia" ]
        && !(selected.home.xdg.configFile ? "systemd/user/dms.service")
      );
    {
      defaults = true;
      selection = true;
      finalStateConflicts = true;
      packages = true;
    };
  directPackages =
    lib.mapAttrs
      (
        name: path:
        let
          cfg = make "nixos" {
            system =
              { pkgs, ... }:
              lib.mkMerge [
                (lib.setAttrByPath (path ++ [ "enable" ]) true)
                {
                  software.packageOverrides.${name} =
                    pkgs.${if name == "dms" then "dms-shell" else name}.overrideAttrs
                      { pname = "custom-${name}"; };
                }
              ];
          };
        in
        valid cfg
        && lib.getName (lib.getAttrFromPath (path ++ [ "package" ]) cfg.system) == "custom-${name}"
        && cfg.system.software.resolved ? ${name}
      )
      {
        dms = [
          "programs"
          "dms-shell"
        ];
        noctalia = [
          "programs"
          "noctalia"
        ];
        noctalia-greeter = [
          "services"
          "displayManager"
          "noctalia-greeter"
        ];
      };
  forced = make "arch" {
    features.noctalia = true;
    system.software.providerOverrides.noctalia = "nix";
  };
in
assert lib.all (value: value) (builtins.attrValues directPackages);
assert valid forced;
assert forced.home.software.resolved.noctalia.provider == "nix";
assert lib.hasPrefix "/nix/store/" (
  builtins.head forced.home.systemd.user.services.noctalia.Service.ExecStart
);
lib.genAttrs [ "nixos" "arch" ] check
