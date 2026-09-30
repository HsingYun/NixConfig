# Presets select defaults; adapters must consume the final upstream-style
# options, including explicit customizations supplied by a host.
{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  ports = (import ../../lib/platforms).definitions;
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  build =
    platform: change:
    let
      bootstrap = import ../fixtures/platform.nix { port = ports.${platform}; };
    in
    (mkHost "FinalState" {
      inherit platform;
      inherit (bootstrap) hardwareConfig;
      features = allOff // (change.features or { });
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
  both = {
    gnome = true;
    niri = true;
  };
  greeter =
    enableCompositor:
    build "arch" {
      system = {
        services.desktopManager.gnome.enable = true;
        services.displayManager.defaultSession = "gnome";
        services.displayManager.dms-greeter.enable = true;
        programs.niri.enable = enableCompositor;
      };
    };
  greeterOnly = greeter true;
  invalidGreeter = builtins.tryEval (valid (greeter false));
  check =
    platform:
    let
      selected = build platform {
        features = both;
        system.services.displayManager.defaultSession = "gnome";
      };
      custom = build platform {
        features = both;
        system.services.greetd.settings.default_session.command = "/custom/greeter --session custom";
      };
      disabled = build platform {
        features.niri = true;
        system.programs.niri.enable = lib.mkForce false;
      };
      direct = build platform {
        features.chinese = true;
        system.services.desktopManager.gnome.enable = true;
      };
      noInput = build platform {
        features.chinese = true;
        system.services.desktopManager.gnome.enable = true;
        home.i18n.inputMethod.enable = lib.mkForce false;
      };
      panel = cfg: lib.hasInfix "kimpanel@kde.org" (builtins.toJSON cfg.home.dconf.settings);
      invalid = builtins.tryEval (valid disabled);
    in
    assert valid selected && valid custom && valid direct && valid noInput;
    assert lib.hasInfix "--cmd gnome-session"
      selected.system.services.greetd.settings.default_session.command;
    assert
      custom.system.services.greetd.settings.default_session.command
      == "/custom/greeter --session custom";
    assert !invalid.success || !invalid.value;
    assert panel direct && !(panel noInput);
    {
      finalSessionControlsCommand = true;
      explicitGreeterCommandPreserved = true;
      disabledDefaultSessionRejected = true;
      inputIntegrationUsesFinalOptions = true;
    };
in
assert valid greeterOnly;
assert !invalidGreeter.success || !invalidGreeter.value;
assert greeterOnly.system.services.displayManager.defaultSession == "gnome";
assert builtins.elem "niri" greeterOnly.system.native.requiredPackages;
assert lib.hasInfix "--command niri"
  greeterOnly.system.services.greetd.settings.default_session.command;
(lib.genAttrs [ "arch" "nixos" ] check) // { greeterCompositorIndependentOfUserSession = true; }
