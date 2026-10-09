{
  lib,
  checks,
  hostChecks,
}:
let
  linux = names: {
    system = "x86_64-linux";
    runner = "ubuntu-24.04";
    checks = names;
  };
  hostCheckNames = system: builtins.attrNames (hostChecks.${system} or { });
  groups = {
    # Keep related fixtures in one evaluator; splitting each report into its own
    # job would repeat input downloads, nixpkgs imports and module setup.
    eval-common = linux [
      "upstream-assumptions"
      "ci-plan"
      "flake-outputs"
      "architecture-boundaries"
      "nixman-unit"
      "application-selection"
      "configuration-layers"
      "feature-rules"
      "host-interface"
      "nixman-generations"
      "nixman-installation"
      "platform-registration"
      "software"
      "software-demand"
      "software-package-policy"
      "software-sources"
    ];
    eval-features = linux [
      "feature-modules"
      "feature-settings"
      "desktop-shells"
      "chinese-input"
      "login-session"
    ];
    eval-contracts = linux [
      "contract-behavior"
      "contract-types"
      "platform-contract-types"
      "native-home-conformance"
      "native-privilege"
      "keyring-providers"
    ];
    linux-runtime = linux [
      "nixman"
      "vim-runtime"
      "mpv-native-files"
      "gpg-build-demand"
      "software-runtime"
      "vscode-settings"
      "kdl-configuration"
      "gdm-session"
      "display-manager-lifecycle"
      "mihomo-configuration"
      "dconf-lifecycle"
      "chrome-policy"
      "pacman-activation"
      "native-system-profile"
      "native-units"
      "network-preflight"
      "native-input-autostart"
      "native-niri-config"
      "native-noctalia-config"
      "desktop-autostart"
      "native-user-units"
      "native-system-backend"
      "native-system-integration"
      "noctalia-configuration"
      "niri-dms-configuration"
      "desktop-boundaries"
      "pacman-migration"
      "greeter-session"
      "owned-root-file"
      "launcher-native"
      "display-manager-activation"
    ];
    # The hosts and toolchain share large package closures. Build them together
    # so a cold run fetches/builds each dependency once within this job.
    linux-profiles = linux ([ "feature-devel" ] ++ hostCheckNames "x86_64-linux");
    # Both VM tests share the NixOS/QEMU closure and run outside the evaluator
    # and desktop-profile jobs' memory/disk budgets.
    linux-vm = linux [
      "mihomo-service"
      "native-systemd-vm"
    ];
    darwin = {
      system = "aarch64-darwin";
      runner = "macos-15";
      checks = [
        "upstream-assumptions"
        "nixman"
        "vim-runtime"
        "mpv-native-files"
        "gpg-build-demand"
        "software-runtime"
        "vscode-settings"
      ]
      ++ hostCheckNames "aarch64-darwin";
    };
  };
in
import ./plan.nix { inherit lib; } { inherit checks groups; }
