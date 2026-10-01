{ inputs, pkgs }:
let
  inherit (import ../../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  greeter =
    (mkHost "GreeterNamespace" {
      platform = "arch";
      features = {
        niri = true;
        noctalia = true;
      };
      homeConfig.home.stateVersion = "26.05";
    }).views.system;
  activation = pkgs.writeText "greeter-activation" greeter.native.activation.selectNativeLoginManager.data;
in
pkgs.testers.runNixOSTest {
  name = "native-systemd-lifecycle";
  # Use acceleration when available, but allow ordinary Linux CI builders.
  requiredFeatures.kvm = false;
  nodes.machine = {
    users.users.greeter-test.isSystemUser = true;
    users.users.greeter-test.group = "greeter-test";
    users.groups.greeter-test = { };
    environment.systemPackages = [
      pkgs.bubblewrap
      pkgs.python3
      pkgs.util-linux
    ];
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("runuser -u greeter-test -- env PYTHONDONTWRITEBYTECODE=1 python3 ${./greeter-configuration-integration.py} ${activation}")
    # Native Arch owns a writable system unit directory; reproduce that layout
    # while leaving the VM's initial NixOS unit definitions available.
    machine.succeed("cp -aH /etc/systemd/system /tmp/systemd-writable")
    machine.succeed("rm /etc/systemd/system && mv /tmp/systemd-writable /etc/systemd/system")
    machine.succeed("PYTHONDONTWRITEBYTECODE=1 python3 ${../common/systemd-integration.py} ${../../../assets/helpers}/common/systemd.py")
  '';
}
