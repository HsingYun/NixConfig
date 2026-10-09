{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  make =
    args:
    (mkHost "NiriService" {
      platform = "arch";
      features = allOff;
      systemConfig.programs.niri.enable = args.enable;
      homeConfig = {
        home.stateVersion = "26.05";
        wayland.windowManager.niri = {
          inherit (args) enable;
          systemd.enable = args.service;
          settings.input.keyboard.xkb.layout = "us";
        };
      };
    }).views.home;
  cases = lib.cartesianProduct {
    enable = [
      false
      true
    ];
    service = [
      false
      true
    ];
  };
  check =
    args:
    let
      h = make args;
      expected = args.enable && args.service;
      unitFiles = lib.filterAttrs (name: _: lib.hasPrefix "systemd/user/niri" name) h.xdg.dataFile;
    in
    assert lib.assertMsg (lib.all (
      a: a.assertion
    ) h.assertions) "Arch Niri service request fails assertions: ${builtins.toJSON args}";
    assert
      builtins.attrNames unitFiles == (lib.optionals expected [
        "systemd/user/niri-shutdown.target"
        "systemd/user/niri.service"
      ]);
    assert lib.all (
      name:
      toString unitFiles.${name}.source == toString (
        h.lib.file.mkOutOfStoreSymlink "${h.native.systemd.user.vendorDirectory}/${baseNameOf name}"
      )
    ) (builtins.attrNames unitFiles);
    assert !(h.systemd.user.services ? niri);
    assert
      h.systemd.user.startServices == (make (args // { service = false; })).systemd.user.startServices;
    assert !(h.xdg.configFile ? "systemd/user/niri.service");
    assert !(h.native.systemd.user.units ? "niri.service");
    assert !args.enable || h.wayland.windowManager.niri.package == null;
    assert !args.enable || h.systemd.user.packages == [ ];
    assert builtins.isString h.home.activationPackage.drvPath;
    true;
  # Exercise the delegated Nix branch against the original module as an oracle.
  nixHome =
    modules:
    (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = {
        inherit inputs;
        osConfig.programs.niri.enable = true;
      };
      modules = [
        {
          home = {
            username = "test";
            homeDirectory = "/home/test";
            stateVersion = "26.05";
          };
          wayland.windowManager.niri = {
            enable = true;
            package = lib.mkForce pkgs.niri;
            portalPackage = lib.mkForce null;
            xwaylandSatellitePackage = lib.mkForce null;
            checkConfig = false;
            systemd.enable = true;
            settings.input.keyboard.xkb.layout = "us";
            extraConfig = "// conformance";
          };
        }
      ]
      ++ modules;
    }).config;
  original = nixHome [ ];
  delegated = nixHome [ ../../ports/arch/home/capabilities/niri.nix ];
in
assert lib.all check cases;
assert lib.all (h: lib.all (a: a.assertion) h.assertions) [
  original
  delegated
];
assert
  original.xdg.configFile."niri/config.kdl".text == delegated.xdg.configFile."niri/config.kdl".text;
assert original.systemd.user.packages == delegated.systemd.user.packages;
assert
  lib.sort builtins.lessThan (map toString original.home.packages)
  == lib.sort builtins.lessThan (map toString delegated.home.packages);
assert original.xdg.dataFile."systemd/user".source == delegated.xdg.dataFile."systemd/user".source;
{
  nativeEnablementMatrix = true;
  nativeUnitsUseSystemRuntime = true;
  compositorLifecycleRemainsWithSession = true;
  nixBranchMatchesUpstream = true;
}
