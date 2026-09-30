{ pkgs, inputs }:
let
  inherit (pkgs) lib;
  render = import ../assets/helpers/arch/pacman-activation.nix { inherit lib; };
  pacman = pkgs.writeShellScript "pacman-stub" ''
    if [[ $1 == -Q ]]; then
      printf '%s\n' "$*" >> "$QUERY_LOG"
      [[ ''${ALL_INSTALLED:-0} == 1 || $3 == installed ]]
    else
      printf 'pacman %s\n' "$*" >> "$INSTALL_LOG"
      exit "''${FAIL_REPO:-0}"
    fi
  '';
  sudo = pkgs.writeShellScript "sudo-stub" ''
    printf 'sudo\n' >> "$INSTALL_LOG"
    exec "$@"
  '';
  yay = pkgs.writeShellScript "yay-stub" ''
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
          inherit pacman sudo yay;
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
  noSudo = script { sudo = "/missing-sudo"; };
  repoOnly = script {
    aur = [ ];
    yay = "/missing-yay";
  };
  aurOnly = script { packages = [ ]; };
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
