{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  contracts = import ../../contracts;
  ports = (import ../../lib/platforms).definitions;
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  check =
    platform: port:
    let
      bootstrap = import ../fixtures/platform.nix { inherit port; };
      probes = scope: { options, pkgs, ... }: {
        assertions = import ../contracts/types.nix {
          inherit lib pkgs options;
          names = lib.filter (name: contracts.${name}.scope == scope) port.contracts;
        };
      };
      host =
        (mkHost "PlatformTypes" {
          inherit platform;
          inherit (bootstrap) hardwareConfig;
          features = allOff;
          stateVersion.home = "26.05";
          systemConfig.imports = [
            bootstrap.systemConfig
            (probes "system")
          ];
          homeConfig = probes "home";
        }).views;
    in
    assert lib.assertMsg (lib.all (a: a.assertion) (
      host.system.assertions ++ host.home.assertions
    )) "Platform ${platform}: a declared contract rejected its portable input types.";
    true;
in
lib.mapAttrs check ports
