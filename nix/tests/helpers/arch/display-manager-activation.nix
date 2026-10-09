{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  check =
    service: previous:
    let
      systemctl = pkgs.writeShellScript "systemctl-stub" ''
        set -euo pipefail
        case "$*" in
          'show --property=LoadState,UnitFileState -- ${service}')
            if [[ ''${FAIL_QUERY:-0} != 0 ]]; then exit "$FAIL_QUERY"; fi
            echo LoadState=loaded
            echo "UnitFileState=$(cat "$TEST_ROOT/manager-state")"; exit 0 ;;
          'show --property=LoadState,UnitFileState -- ${previous}')
            echo LoadState=loaded
            if [[ -e "$TEST_ROOT/previous-disabled" ]]; then echo UnitFileState=disabled; else echo UnitFileState=enabled; fi
            exit 0 ;;
          'get-default') cat "$TEST_ROOT/boot-target"; exit 0 ;;
        esac
        printf '%s\n' "$*" >> "$TEST_ROOT/actions"
        case "$*" in
          'enable --force ${service}')
            if [[ ''${FAIL_ENABLE:-0} != 0 ]]; then exit "$FAIL_ENABLE"; fi
            ln -sfn "$TEST_ROOT/units/${service}" "$TEST_ROOT/display-manager.service"
            echo enabled > "$TEST_ROOT/manager-state"
            ;;
          'disable -- ${previous}')
            test "$(readlink "$TEST_ROOT/display-manager.service")" = "$TEST_ROOT/units/${service}"
            if [[ ''${FAIL_DISABLE:-0} != 0 ]]; then exit "$FAIL_DISABLE"; fi
            touch "$TEST_ROOT/previous-disabled"
            ;;
          'daemon-reload') ;;
          'set-default graphical.target') echo graphical.target > "$TEST_ROOT/boot-target" ;;
          *) echo "Unexpected system mutation: $*" >&2; exit 99 ;;
        esac
      '';
      sudo = pkgs.writeShellScript "sudo-stub" ''exec "$@"'';
      activate = pkgs.writeShellScript "display-manager-activation-test" ''
        set -euo pipefail
        source ${inputs.home-manager}/lib/bash/home-manager.sh
        ${import ../../../assets/helpers/arch/display-manager-activation.nix { inherit lib pkgs; } {
          inherit
            systemctl
            service
            ;
          privilegeCommand = [ sudo ];
          stateFile = "test-root/state/display-manager.json";
          files = [
            {
              source = "test-root/source";
              destination = "test-root/config/managed.conf";
              stateFile = "test-root/state/managed.json";
            }
          ];
          displayManagerLink = "test-root/display-manager.service";
        }}
      '';
    in
    pkgs.runCommand "display-manager-activation-check" { } ''
      export TEST_ROOT="$PWD/test-root"
      mkdir -p "$TEST_ROOT/units"
      touch "$TEST_ROOT/units/${service}" "$TEST_ROOT/units/${previous}"
      echo disabled > "$TEST_ROOT/manager-state"
      echo multi-user.target > "$TEST_ROOT/boot-target"
      : > "$TEST_ROOT/actions"
      echo configuration > "$TEST_ROOT/source"
      ln -s "$TEST_ROOT/units/${previous}" "$TEST_ROOT/display-manager.service"

      DRY_RUN=1 ${activate} > dry-run
      test ! -s "$TEST_ROOT/actions"
      test "$(readlink "$TEST_ROOT/display-manager.service")" = "$TEST_ROOT/units/${previous}"

      test ! -e "$TEST_ROOT/config/managed.conf"
      set +e
      FAIL_ENABLE=42 ${activate}
      status=$?
      set -e
      test "$status" -eq 42
      test ! -e "$TEST_ROOT/previous-disabled"
      test "$(readlink "$TEST_ROOT/display-manager.service")" = "$TEST_ROOT/units/${previous}"

      test "$(cat "$TEST_ROOT/config/managed.conf")" = configuration
      : > "$TEST_ROOT/actions"
      rm "$TEST_ROOT/config/managed.conf"
      ${activate}
      cat > expected <<'EOF'
      daemon-reload
      enable --force ${service}
      disable -- ${previous}
      set-default graphical.target
      EOF
      diff -u expected "$TEST_ROOT/actions"

      # Query failure is not evidence that a login manager is disabled.
      : > "$TEST_ROOT/actions"
      if FAIL_QUERY=44 ${activate}; then exit 1; fi
      test ! -s "$TEST_ROOT/actions"
      test -e "$TEST_ROOT/previous-disabled"
      ${activate}
      test ! -s "$TEST_ROOT/actions"

      # Failure after replacing the alias must still clean up on retry.
      rm "$TEST_ROOT/previous-disabled"
      set +e
      FAIL_DISABLE=43 ${activate}
      status=$?
      set -e
      test "$status" -eq 43
      test ! -e "$TEST_ROOT/previous-disabled"
      ${activate}
      test -e "$TEST_ROOT/previous-disabled"
      : > "$TEST_ROOT/actions"
      ${activate}
      test ! -s "$TEST_ROOT/actions"

      # First install with no previous display manager, already a graphical boot.
      rm "$TEST_ROOT/display-manager.service"
      echo disabled > "$TEST_ROOT/manager-state"
      : > "$TEST_ROOT/actions"
      ${activate}
      test "$(cat "$TEST_ROOT/actions")" = 'enable --force ${service}'
      touch "$out"
    '';
in
pkgs.linkFarm "display-manager-activation-checks" [
  {
    name = "gdm";
    path = check "gdm.service" "greetd.service";
  }
  {
    name = "greetd";
    path = check "greetd.service" "gdm.service";
  }
]
