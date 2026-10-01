{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  plan = pkgs.writeText "backend-test-plan.json" (
    builtins.toJSON {
      version = 1;
      owner = "test";
      host = "PortableNative";
      resources.example = {
        desired = "configured";
        check = null;
      };
      stages.example = { };
    }
  );
  command = "${pkgs.python3}/bin/python3 ${../../../assets/helpers}/common/system-backend.py --plan ${plan} --state test-state";
  wrap =
    script:
    import ../../../assets/helpers/common/system-stage.nix { inherit lib; } {
      inherit script command;
      name = "example";
    };
  activation =
    body:
    pkgs.writeShellScript "test-native-activation" ''
      set -euo pipefail
      source ${inputs.home-manager}/lib/bash/home-manager.sh
      run ${command} begin --pid "$$"
      ${wrap body}
      run ${command} stage-start --pid "$$" --stage verification
      run ${command} complete --pid "$$"
    '';
  success = activation "touch applied";
  failure = activation ''
    ${pkgs.bash}/bin/bash -c 'exit 42'
    touch must-not-run
  '';
  dryRun = activation "run touch dry-run-must-not-run";
in
pkgs.runCommand "native-system-backend-check"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.jq
    ];
  }
  ''
    export PYTHONDONTWRITEBYTECODE=1
    python3 ${./system-backend.py} ${../../../assets/helpers}/common
    DRY_RUN=1 ${dryRun}
    test ! -e test-state
    test ! -e dry-run-must-not-run
    ${success}
    jq -e '.attempt.status == "succeeded"' test-state/state.json
    set +e
    ${failure}
    result=$?
    set -e
    test "$result" -eq 42
    test ! -e must-not-run
    jq -e '.attempt.status == "failed" and .attempt.exitCode == 42 and .successful != null' test-state/state.json
    ${success}
    jq -e '.attempt.status == "succeeded"' test-state/state.json
    touch "$out"
  ''
