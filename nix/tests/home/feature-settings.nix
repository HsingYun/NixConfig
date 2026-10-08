{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  ports = (import ../../lib/platforms).definitions;
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  make =
    platform: enabled: extra:
    let
      bootstrap = import ../fixtures/platform.nix { port = ports.${platform}; };
    in
    (mkHost "FeatureSettings" {
      inherit platform;
      inherit (bootstrap) hardwareConfig systemConfig;
      stateVersion.home = "26.05";
      features = allOff // {
        ghostty = enabled;
        mpv = enabled;
      };
      featureConfig = {
        ghostty.settings = {
          font-size = 18;
          background-opacity = 1.0;
        };
        mpv = {
          settings = {
            hwdec = "no";
            interpolation = false;
          };
          scriptOpts.osc.language = "eng";
        };
      };
      homeConfig = extra;
    }).views;
  check =
    platform:
    let
      on = make platform true { };
      off = make platform false { };
      forced = make platform true {
        programs.ghostty.settings.font-size = lib.mkForce 22;
        programs.mpv.config.hwdec = lib.mkForce "auto-safe";
      };
    in
    assert lib.all (cfg: lib.all (a: a.assertion) (cfg.home.assertions ++ cfg.system.assertions)) [
      on
      off
      forced
    ];
    assert on.home.programs.ghostty.settings.font-size == [ 18 ];
    assert on.home.programs.ghostty.settings.font-family == [ "Maple Mono NF CN" ];
    assert on.home.programs.mpv.config.hwdec == "no";
    assert !on.home.programs.mpv.config.interpolation;
    assert on.home.programs.mpv.config.vo == "gpu-next";
    assert on.home.programs.mpv.scriptOpts.osc.language == "eng";
    assert forced.home.programs.ghostty.settings.font-size == [ 22 ];
    assert forced.home.programs.mpv.config.hwdec == "auto-safe";
    assert !(off.home.xdg.configFile ? "ghostty/config");
    assert !(off.home.xdg.configFile ? "mpv/mpv.conf");
    true;
  niri =
    chinese: homeConfig:
    (mkHost "NiriIntegration" {
      platform = "arch";
      stateVersion.home = "26.05";
      features = allOff // {
        niri = true;
        inherit chinese;
      };
      inherit homeConfig;
    }).views;
  plain = niri false { };
  localized = niri true { home.language.base = "en_US.UTF-8"; };
  inputOff = niri true { i18n.inputMethod.enable = false; };
  removedVariables = niri true { home.sessionVariables = lib.mkForce { }; };
  customModifiers = niri true { home.sessionVariables.XMODIFIERS = lib.mkForce "@im=custom"; };
  env = cfg: cfg.home.wayland.windowManager.niri.settings.environment;

in
assert lib.all (cfg: lib.all (a: a.assertion) (cfg.home.assertions ++ cfg.system.assertions)) [
  plain
  localized
  inputOff
  removedVariables
  customModifiers
];
assert (env plain).QT_QPA_PLATFORMTHEME == "gtk3";
assert (env plain).ELECTRON_OZONE_PLATFORM_HINT == "auto";
assert !((env plain) ? GTK_IM_MODULE) && !((env plain) ? LANG);
assert (env localized).LANG == "en_US.UTF-8" && (env localized).GTK_IM_MODULE == null;
assert !((env inputOff) ? GTK_IM_MODULE);
assert !((env removedVariables) ? XMODIFIERS);
assert (env customModifiers).XMODIFIERS == "@im=custom";
lib.genAttrs [ "arch" "nixos" "darwin" ] check
