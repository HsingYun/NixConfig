{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  registry = (import ../../lib/platforms).definitions;
  catalog = (import ../../lib/features/catalog.nix { inherit lib; }).features;
  allOff = lib.genAttrs (builtins.attrNames catalog) (_: false);
  make =
    platform: extra:
    let
      bootstrap = import ../fixtures/platform.nix { port = registry.${platform}; };
    in
    (mkHost "MihomoTest" (
      {
        inherit platform;
        features = allOff // {
          mihomo = true;
        };
        featureConfig.mihomo.configFile = "/does-not-exist/private-mihomo.yaml";
        inherit (bootstrap) hardwareConfig systemConfig;
        homeConfig.home.stateVersion = "26.05";
      }
      // extra
    )).views.system;
  nixos = make "nixos" { };
  arch = make "arch" { };
  darwin = make "darwin" { };
  archNix = make "arch" { packageManager = "nix"; };
  darwinNix = make "darwin" { packageManager = "nix"; };
  noTun = make "arch" {
    featureConfig.mihomo = {
      configFile = "/private.yaml";
      tunMode = false;
    };
  };
  invalid = make "nixos" {
    featureConfig.mihomo.configFile = toString (pkgs.writeText "must-not-store-secrets" "secret");
  };
  archOff = make "arch" { features = allOff; };
  darwinOff = make "darwin" { features = allOff; };
  directUpstream = make "nixos" {
    features = allOff;
    systemConfig = {
      system.stateVersion = "26.11";
      services.mihomo = {
        enable = true;
        configFile = pkgs.writeText "public-mihomo-config" "mode: direct\n";
      };
    };
  };
  nativeUnit = arch.native.systemd.definitions."mihomo.service";
in
assert lib.all (cfg: lib.all (a: a.assertion) cfg.assertions) [
  nixos
  arch
  darwin
  archNix
  darwinNix
  noTun
  directUpstream
];
assert !builtins.elem "nixos-wsl" catalog.mihomo.platforms;
assert nixos.services.mihomo.tunMode;
assert nixos.systemd.services.mihomo.serviceConfig.DynamicUser;
assert
  nixos.systemd.services.mihomo.serviceConfig.LoadCredential
  == "config.yaml:/does-not-exist/private-mihomo.yaml";
assert builtins.elem "multi-user.target" nixos.systemd.services.mihomo.wantedBy;
assert builtins.elem "mihomo" arch.software.plan.installations.pacman.aur;
assert nativeUnit.Service.LoadCredential == "config.yaml:/does-not-exist/private-mihomo.yaml";
assert lib.hasInfix "/usr/bin/mihomo" nativeUnit.Service.ExecStart;
assert nativeUnit.Service.AmbientCapabilities == "CAP_NET_ADMIN";
assert noTun.native.systemd.definitions."mihomo.service".Service.AmbientCapabilities == "";
assert lib.hasPrefix "${archNix.services.mihomo.package}/bin/mihomo "
  archNix.native.systemd.definitions."mihomo.service".Service.ExecStart;
assert darwin.launchd.daemons.mihomo.serviceConfig.RunAtLoad;
assert darwin.launchd.daemons.mihomo.serviceConfig.UserName == "root";
assert builtins.elem "mihomo" darwin.software.plan.installations.homebrew.brews;
assert
  lib.head darwinNix.launchd.daemons.mihomo.serviceConfig.ProgramArguments
  == "${darwinNix.services.mihomo.package}/bin/mihomo";
assert !(archOff.native.systemd.definitions ? "mihomo.service");
assert !(darwinOff.launchd.daemons ? mihomo);
assert lib.any (a: !a.assertion && lib.hasInfix "runtime configFile" a.message) invalid.assertions;
pkgs.runCommand "mihomo-configuration-check" { } ''
  # Build the native service definition as well as evaluating its declaration.
  test -s ${(pkgs.formats.systemd { }).generate "mihomo.service" nativeUnit}
  touch "$out"
''
