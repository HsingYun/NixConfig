{ pkgs, inputs }:
let
  inherit (pkgs) lib;
  render = import ../../../assets/helpers/arch/pacman-activation.nix { inherit lib pkgs; };
  pacman = pkgs.writeShellScript "pacman-stub" ''
    if [[ $1 == -Qq ]]; then
      printf '%s\n' "$*" >> "$QUERY_LOG"
      if [[ ''${FAIL_QUERY:-0} != 0 ]]; then exit "$FAIL_QUERY"; fi
      echo installed
      if [[ ''${ALL_INSTALLED:-0} == 1 ]]; then printf '%s\n' new-repo new-aur; fi
      exit 0
    else
      printf 'pacman %s\n' "$*" >> "$INSTALL_LOG"
      exit "''${FAIL_REPO:-0}"
    fi
  '';
  sudo = pkgs.writeShellScript "sudo-stub" ''
    export NATIVE_ELEVATED=1
    printf 'sudo\n' >> "$INSTALL_LOG"
    exec "$@"
  '';
  yay = pkgs.writeShellScript "yay-stub" ''
    set -euo pipefail
    test "''${NATIVE_ELEVATED:-0}" = 0
    [[ $1 == --sudo && $3 == --sudoflags && -z $4 ]]
    test -x "$2"
    if [[ ''${EXERCISE_YAY_ELEVATION:-0} == 1 ]]; then
      "$2" ${pkgs.coreutils}/bin/true
    fi
    shift 4
    printf 'yay %s\n' "$*" >> "$INSTALL_LOG"
    exit "''${FAIL_AUR:-0}"
  '';
  script =
    overrides:
    pkgs.writeShellScript "native-activation-test" ''
      set -euo pipefail
      source ${inputs.home-manager}/lib/bash/home-manager.sh
      ${render (
        {
          inherit pacman yay;
          privilegeCommand = [ sudo ];
          packages = [
            "installed"
            "new-repo"
          ];
          aur = [ "new-aur" ];
        }
        // overrides
      )}
    '';
  normal = script { };
  noYay = script { yay = "/missing-yay"; };
  noPacman = script { pacman = "/missing-pacman"; };
  noSudo = script { privilegeCommand = [ "/missing-sudo" ]; };
  repoOnly = script {
    aur = [ ];
    yay = "/missing-yay";
  };
  aurOnly = script { packages = [ ]; };
  argumentPrefix = pkgs.writeShellScript "argument-prefix" ''
    set -euo pipefail
    [[ $1 == '--label=two words' ]]
    shift
    exec ${sudo} "$@"
  '';
  configuredPrefix = script {
    privilegeCommand = [
      argumentPrefix
      "--label=two words"
    ];
  };
in
pkgs.runCommand "pacman-activation-check" { } ''
  export INSTALL_LOG="$TMPDIR/install.log" QUERY_LOG="$TMPDIR/query.log"
  clearLogs() { : > "$INSTALL_LOG"; : > "$QUERY_LOG"; }
  clearLogs
  ${normal}
  cat > expected <<'EXPECTED'
  sudo
  pacman -S --needed -- new-repo
  yay -S --needed --aur -- new-aur
  EXPECTED
  diff -u expected "$INSTALL_LOG"

  # The same multi-argument prefix reaches pacman directly and yay indirectly;
  # yay itself must never execute inside that elevated context.
  clearLogs
  EXERCISE_YAY_ELEVATION=1 ${configuredPrefix}
  test "$(grep -c '^sudo$' "$INSTALL_LOG")" -eq 2
  grep -F 'yay -S --needed --aur -- new-aur' "$INSTALL_LOG"

  clearLogs
  if FAIL_QUERY=42 ${normal} > failure 2>&1; then exit 1; fi
  grep -F 'cannot read the installed package database' failure
  test ! -s "$INSTALL_LOG"

  clearLogs
  ALL_INSTALLED=1 ${normal}
  test ! -s "$INSTALL_LOG"
  # Missing tools do not block an entirely satisfied manifest.
  ALL_INSTALLED=1 ${noYay}
  ALL_INSTALLED=1 ${noSudo}
  test ! -s "$INSTALL_LOG"

  clearLogs
  DRY_RUN=1 ${noPacman} > dry-run
  grep -F -- '--aur -- new-aur' dry-run
  test ! -s "$INSTALL_LOG"
  test ! -s "$QUERY_LOG"

  for script in ${noYay} ${noPacman} ${noSudo}; do
    clearLogs
    if "$script" > failure 2>&1; then
      echo "Expected preflight failure" >&2; exit 1
    fi
    grep -F 'Software:' failure
    test ! -s "$INSTALL_LOG"
  done

  clearLogs
  ${repoOnly}
  test "$(wc -l < "$INSTALL_LOG")" -eq 2
  ! grep -F yay "$INSTALL_LOG"

  clearLogs
  ${aurOnly}
  test "$(wc -l < "$INSTALL_LOG")" -eq 1
  grep -F 'yay -S --needed --aur -- new-aur' "$INSTALL_LOG"

  clearLogs
  set +e
  FAIL_REPO=42 ${normal}
  status=$?
  set -e
  test "$status" -eq 42
  ! grep -F yay "$INSTALL_LOG"

  clearLogs
  set +e
  FAIL_AUR=43 ${normal}
  status=$?
  set -e
  test "$status" -eq 43
  touch "$out"
''
