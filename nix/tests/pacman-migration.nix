{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  pacman = pkgs.writeShellScript "pacman-migration-stub" ''
    set -eu
    if [[ $1 == -Qqo ]]; then
      if [[ -e "$TEST_ROOT/login-shell" ]]; then echo htop; exit 0; fi
      exit 1
    fi
    if [[ $1 == -Qlq ]]; then
      if [[ -e "$TEST_ROOT/system-service" ]]; then echo /usr/lib/systemd/system/test.service; fi
      exit 0
    fi
    if [[ $1 == -Q ]]; then test -f "$TEST_ROOT/$3"; exit $?; fi
    [[ $* == '-R --noconfirm -- htop' ]]
    echo "$*" >> "$TEST_ROOT/actions"
    if [[ -e "$TEST_ROOT/dependent" ]]; then exit 42; fi
    rm "$TEST_ROOT/htop"
  '';
  getent = pkgs.writeShellScript "getent-stub" "echo 'test:x:1000:1000::/home/test:/usr/bin/test-shell' ";
  systemctl = pkgs.writeShellScript "systemctl-stub" ''test -e "$TEST_ROOT/system-service" '';
  sudo = pkgs.writeShellScript "sudo-stub" ''exec "$@"'';
  activate = pkgs.writeShellScript "migration-test" ''
    set -euo pipefail
    source ${inputs.home-manager}/lib/bash/home-manager.sh
    ${import ../assets/helpers/pacman-migration.nix { inherit lib; } {
      inherit
        pacman
        sudo
        getent
        systemctl
        ;
      packages = [
        "htop"
        "absent"
      ];
    }}
  '';
in
pkgs.runCommand "pacman-migration-check" { } ''
  export TEST_ROOT="$PWD/state"
  mkdir "$TEST_ROOT"
  touch "$TEST_ROOT/htop" "$TEST_ROOT/unrelated" "$TEST_ROOT/dependent"
  DRY_RUN=1 ${activate}
  test -f "$TEST_ROOT/htop"
  test ! -e "$TEST_ROOT/actions"
  touch "$TEST_ROOT/login-shell"
  if ${activate}; then exit 1; fi
  test ! -e "$TEST_ROOT/actions"
  rm "$TEST_ROOT/login-shell"
  touch "$TEST_ROOT/system-service"
  if ${activate}; then exit 1; fi
  test ! -e "$TEST_ROOT/actions"
  rm "$TEST_ROOT/system-service"
  if ${activate}; then exit 1; fi
  test -f "$TEST_ROOT/htop"
  test -f "$TEST_ROOT/unrelated"
  rm "$TEST_ROOT/dependent"
  ${activate}
  test ! -f "$TEST_ROOT/htop"
  test -f "$TEST_ROOT/unrelated"
  test "$(wc -l < "$TEST_ROOT/actions")" -eq 2
  ${activate}
  test "$(wc -l < "$TEST_ROOT/actions")" -eq 2
  touch "$out"
''
