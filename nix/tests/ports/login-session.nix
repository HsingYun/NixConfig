{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  ports = (import ../../lib/platforms).definitions;
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  make =
    platform: session: manager:
    let
      bootstrap = import ../fixtures/platform.nix { port = ports.${platform}; };
    in
    (mkHost "LoginSession" {
      inherit platform;
      features = allOff;
      inherit (bootstrap) hardwareConfig;
      homeConfig.home.stateVersion = "26.05";
      systemConfig = {
        imports = [ bootstrap.systemConfig ];
        services.desktopManager.gnome.enable = true;
        programs.niri.enable = true;
        services.displayManager = {
          gdm.enable = manager == "gdm";
          defaultSession = session;
        };
        services.greetd.enable = manager == "greetd";
      };
    }).views;
  valid = cfg: lib.all (a: a.assertion) (cfg.system.assertions ++ cfg.home.assertions);
  file =
    cfg:
    lib.findFirst (
      f: f.destination == "/etc/systemd/system/gdm.service.d/nixconfig.conf"
    ) null cfg.system.native.resources.loginManager.desired.files;
  check =
    platform:
    let
      gnome = make platform "gnome" "gdm";
      niri = make platform "niri" "gdm";
      unset = make platform null "gdm";
    in
    assert lib.all valid [
      gnome
      niri
      unset
    ];
    if platform == "arch" then
      let
        off = make platform "gnome" "none";
        greetd = make platform "niri" "greetd";
        stage = niri.system.native.activation.checkNativeGdmSession;
      in
      assert valid off && valid greetd;
      assert file gnome != null && file niri != null && (file gnome).source != (file niri).source;
      assert lib.all (cfg: file cfg == null && !(cfg.system.native.activation ? checkNativeGdmSession)) [
        unset
        off
        greetd
      ];
      assert
        builtins.elem "installNativePackages" stage.after && builtins.elem "linkGeneration" stage.before;
      assert lib.hasInfix "--check" stage.data;
      assert builtins.elem "accountsservice" niri.system.native.requiredPackages;
      {
        parameterChangesDeployment = true;
        unsetRetiresConfiguration = true;
        preflightBeforeSelection = true;
      }
    else
      let
        preStart = cfg: cfg.system.systemd.services.display-manager.preStart;
      in
      assert lib.hasInfix "/bin/set-session gnome" (preStart gnome);
      assert lib.hasInfix "/bin/set-session niri" (preStart niri);
      assert !lib.hasInfix "/bin/set-session" (preStart unset);
      {
        delegatesToUpstream = true;
      };
in
lib.genAttrs [ "arch" "nixos" ] check
