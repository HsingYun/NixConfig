{ pkgs, inputs }:
let
  inherit (pkgs) lib;
  sudo = pkgs.writeShellScript "sudo-stub" ''exec "$@"'';
  script =
    active:
    pkgs.writeShellScript "chrome-policy-test" ''
      set -euo pipefail
      source ${inputs.home-manager}/lib/bash/home-manager.sh
      ${import ../../../assets/helpers/common/owned-root-file.nix { inherit lib pkgs; } {
        inherit active sudo;
        text = builtins.toJSON { ExtensionSettings.example.installation_mode = "normal_installed"; };
        destination = "test-root/policies/nixconfig-extensions.json";
        stateFile = "test-root/state/chrome.json";
      }}
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
