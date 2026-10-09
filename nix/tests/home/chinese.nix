{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  ports = (import ../../lib/platforms).definitions;
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  make =
    platform: args:
    let
      bootstrap = import ../fixtures/platform.nix { port = ports.${platform}; };
    in
    (mkHost "ChineseInput" (
      {
        inherit platform;
        inherit (bootstrap) hardwareConfig systemConfig;
        stateVersion.home = "26.05";
        features = allOff;
      }
      // args
    )).views;
  basicInput.i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
  };
  chineseFeatures = allOff // {
    chinese = true;
  };
  valid = views: lib.all (a: a.assertion) (views.home.assertions ++ views.system.assertions);
  hasPreset =
    home:
    home.xdg.dataFile ? "fcitx5/rime/default.custom.yaml"
    && home.xdg.dataFile ? "fcitx5/rime/rime_ice.custom.yaml";
  check =
    platform:
    let
      bare = make platform { homeConfig = basicInput; };
      on = make platform { features = chineseFeatures; };
      off = make platform { };
      chinese = on.home;
    in
    assert lib.all valid [
      bare
      on
      off
    ];
    assert !hasPreset bare.home && !hasPreset off.home;
    assert !(bare.home.software.resolved ? fcitx5-rime);
    assert !(bare.home.software.resolved ? rime-ice);
    assert bare.home.i18n.inputMethod.fcitx5.addons == [ ];
    assert hasPreset chinese;
    assert chinese.i18n.inputMethod.fcitx5.settings.inputMethod."Groups/0".DefaultIM == "rime";
    assert
      if platform == "arch" then
        bare.home.software.plan.installations.pacman.aur == [ ]
        && builtins.elem "fcitx5-rime" chinese.software.plan.installations.pacman.packages
        && builtins.elem "rime-ice-git" chinese.software.plan.installations.pacman.aur
        && chinese.i18n.inputMethod.fcitx5.addons == [ ]
      else
        chinese.software.resolved.fcitx5-rime.provider == "nix"
        && builtins.elem chinese.software.resolved.fcitx5-rime.package chinese.i18n.inputMethod.fcitx5.addons;
    true;
  inputOff = make "arch" {
    features = chineseFeatures;
    homeConfig.i18n.inputMethod.enable = false;
  };
  incompatible = make "arch" {
    features = chineseFeatures;
    homeConfig.software.providerOverrides.fcitx5-rime = "nix";
  };
  explicitExtra = make "arch" {
    homeConfig = basicInput;
    packageManager = {
      type = "pacman";
      extraPkg.pacman.aur = [ "rime-ice-git" ];
    };
  };
in
assert valid inputOff && valid explicitExtra;
assert !(inputOff.home.software.resolved ? fcitx5-rime);
assert !(inputOff.home.software.resolved ? rime-ice);
assert !(builtins.elem "fcitx5-rime" inputOff.home.software.plan.installations.pacman.packages);
assert !(builtins.elem "rime-ice-git" inputOff.home.software.plan.installations.pacman.aur);
assert !(builtins.tryEval incompatible.home.home.activationPackage.drvPath).success;
assert explicitExtra.home.software.plan.installations.pacman.aur == [ "rime-ice-git" ];
{
  platforms = lib.genAttrs [ "arch" "nixos" ] check;
  disabledNativeInputDropsRimeDependencies = true;
  incompatibleNixAddonRejected = true;
  explicitNativeExtrasPreserved = true;
}
