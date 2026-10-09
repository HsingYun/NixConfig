{ pkgs, inputs }:
let
  lib = pkgs.lib.extend (_: _: { inherit (inputs.home-manager.lib) hm; });
  sudo = pkgs.writeShellScript "sudo-stub" ''exec "$@"'';
  destination = "/etc/opt/chrome/policies/managed/nixconfig-extensions.json";
  state = "/var/lib/nixconfig/files/${builtins.hashString "sha256" destination}.json";
  policy = {
    ExtensionSettings.example.installation_mode = "normal_installed";
    ContractProbe = true;
  };
  script =
    enabled:
    let
      # Render the production adapter, retaining its real enabled/disabled
      # logic, payload and helper. Only privileged paths and sudo are sandboxed.
      module = import ../../../ports/arch/activation/chrome.nix {
        inherit lib pkgs;
        user.username = "test";
        config.native.privilegeCommand = [ sudo ];
        config.programs.chromium = {
          enable = enabled;
          extraOpts = policy;
        };
      };
      activation =
        lib.replaceStrings
          [ destination state ]
          [ "test-root/policies/nixconfig-extensions.json" "test-root/state/chrome.json" ]
          module.native.activation.installChromePolicy.data;
    in
    pkgs.writeShellScript "chrome-policy-test" ''
      set -euo pipefail
      source ${inputs.home-manager}/lib/bash/home-manager.sh
      ${activation}
    '';
  enabled = script true;
  disabled = script false;
in
pkgs.runCommand "chrome-policy-check" { } ''
  ${disabled}
  test ! -e test-root
  DRY_RUN=1 ${enabled}
  test ! -e test-root
  ${enabled}
  cmp test-root/policies/nixconfig-extensions.json ${pkgs.writeText "expected-chrome-policy.json" (builtins.toJSON policy)}
  cp test-root/policies/nixconfig-extensions.json expected
  ${enabled}
  cmp expected test-root/policies/nixconfig-extensions.json
  echo unrelated > test-root/policies/other.json
  ${disabled}
  test ! -e test-root/policies/nixconfig-extensions.json
  test "$(cat test-root/policies/other.json)" = unrelated
  ${disabled}
  ${enabled}
  echo administrator > test-root/policies/nixconfig-extensions.json
  if ${enabled}; then exit 1; fi
  if ${disabled}; then exit 1; fi
  test "$(cat test-root/policies/nixconfig-extensions.json)" = administrator
  touch "$out"
''
