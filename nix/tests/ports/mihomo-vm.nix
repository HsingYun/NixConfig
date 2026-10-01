{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  native =
    (mkHost "MihomoRuntime" {
      platform = "arch";
      packageManager = "nix";
      features = allOff // {
        mihomo = true;
      };
      featureConfig.mihomo.configFile = "/run/mihomo-private.yaml";
      homeConfig.home.stateVersion = "26.05";
    }).views.system;
  unit =
    (pkgs.formats.systemd { }).generate "mihomo.service"
      native.native.systemd.definitions."mihomo.service";
  # Public test data only. Production private files are never Nix inputs.
  fixture = pkgs.writeText "mihomo-test.yaml" ''
    mode: direct
    ipv6: false
    tun:
      enable: true
      device: mihomotest
      stack: system
      auto-route: true
      auto-detect-interface: true
  '';
in
pkgs.testers.runNixOSTest {
  name = "mihomo-private-config-tun";
  requiredFeatures.kvm = false;
  nodes = {
    upstream = {
      boot.kernelModules = [ "tun" ];
      services.mihomo = {
        enable = true;
        tunMode = true;
        configFile = "/run/mihomo-private.yaml";
      };
    };
    native = {
      boot.kernelModules = [ "tun" ];
    };
  };
  testScript = ''
    start_all()
    for node in (upstream, native):
        node.wait_for_unit("multi-user.target")
    native.succeed("cp ${unit} /run/systemd/system/mihomo.service; systemctl daemon-reload")
    for node in (upstream, native):
        # Missing private configuration must remain a visible startup error.
        node.fail("systemctl start mihomo.service")
        node.succeed("systemctl stop mihomo.service")
        node.succeed("install -m 600 ${fixture} /run/mihomo-private.yaml")
        node.succeed("systemctl start mihomo.service")
        node.wait_for_unit("mihomo.service")
        node.wait_until_succeeds("ip link show mihomotest")
        node.succeed("test $(stat -c %a /run/mihomo-private.yaml) = 600")
        node.succeed("systemctl stop mihomo.service")
        node.wait_until_fails("ip link show mihomotest")
        node.succeed("test -f /run/mihomo-private.yaml")
  '';
}
