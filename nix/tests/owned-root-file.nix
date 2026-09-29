{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  sudo = pkgs.writeShellScript "sudo-stub" ''exec "$@"'';
  activation =
    active: text:
    pkgs.writeShellScript "owned-root-file-test" ''
      set -euo pipefail
      source ${inputs.home-manager}/lib/bash/home-manager.sh
      ${import ../assets/helpers/owned-root-file.nix { inherit lib pkgs; } {
        inherit active text sudo;
        destination = "test-root/system/policy.rules";
        stateFile = "test-root/state/policy.json";
      }}
    '';
  first = activation true "first rule\n";
  second = activation true "second rule\n";
  disabled = activation false "";
in
pkgs.runCommand "owned-root-file-check" { } ''
  ${disabled}
  test ! -e test-root
  DRY_RUN=1 ${first}
  test ! -e test-root

  ${first}
  test "$(cat test-root/system/policy.rules)" = 'first rule'
  test -f test-root/state/policy.json
  ${second}
  test "$(cat test-root/system/policy.rules)" = 'second rule'
  ${second}
  DRY_RUN=1 ${disabled}
  test -f test-root/system/policy.rules
  ${disabled}
  test ! -e test-root/system/policy.rules
  test ! -e test-root/state/policy.json

  # Neither initial activation nor later cleanup may overwrite external edits.
  echo 'administrator rule' > test-root/system/policy.rules
  if ${first}; then exit 1; fi
  test "$(cat test-root/system/policy.rules)" = 'administrator rule'
  rm test-root/system/policy.rules
  ${first}
  echo 'administrator rule' > test-root/system/policy.rules
  if ${disabled}; then exit 1; fi
  test "$(cat test-root/system/policy.rules)" = 'administrator rule'
  test -f test-root/state/policy.json

  # Symlinks must never be followed for privileged file writes or deletion.
  rm test-root/system/policy.rules
  echo untouched > test-root/victim
  ln -s ../victim test-root/system/policy.rules
  if ${second}; then exit 1; fi
  if ${disabled}; then exit 1; fi
  test "$(cat test-root/victim)" = untouched
  # A symlinked parent may not redirect either updates or cleanup.
  rm test-root/system/policy.rules
  rmdir test-root/system
  mkdir test-root/elsewhere
  echo untouched > test-root/elsewhere/policy.rules
  ln -s elsewhere test-root/system
  if ${second}; then exit 1; fi
  if ${disabled}; then exit 1; fi
  test "$(cat test-root/elsewhere/policy.rules)" = untouched
  rm test-root/system
  mkdir test-root/system
  rm test-root/state/policy.json

  # Matching content alone is not ownership: never adopt an administrator file.
  echo 'first rule' > test-root/system/policy.rules
  if ${first}; then exit 1; fi
  ${disabled}
  test "$(cat test-root/system/policy.rules)" = 'first rule'
  ${pkgs.python3}/bin/python3 - ${../assets/helpers} <<'PY'
  import importlib.util, pathlib, sys, tempfile
  directory = pathlib.Path(sys.argv[1])
  sys.path.insert(0, str(directory))
  spec = importlib.util.spec_from_file_location("owned_file", directory / "owned-file.py")
  helper = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(helper)
  with tempfile.TemporaryDirectory() as tmp:
      base = pathlib.Path(tmp)
      dest, state, source = [base / name for name in ["destination", "state.json", "source"]]
      source.write_text("shared")
      helper.reconcile(dest, state, source, "alice")
      helper.reconcile(dest, state, source, "bob")
      helper.reconcile(dest, state, None, "alice")
      assert dest.read_text() == "shared"
      source.write_text("conflict")
      try:
          helper.reconcile(dest, state, source, "alice")
      except RuntimeError:
          pass
      else:
          raise AssertionError("overwrote another owner's policy")
      helper.reconcile(dest, state, None, "bob")
      assert not dest.exists()
      helper.reconcile(dest, state, source, "alice")
      # Identical bytes in a replacement inode are still an external replacement.
      replacement = base / "replacement"
      replacement.write_bytes(dest.read_bytes())
      replacement.replace(dest)
      try:
          helper.reconcile(dest, state, None, "alice")
      except RuntimeError:
          pass
      else:
          raise AssertionError("deleted externally replaced file")
      assert dest.read_text() == "conflict"
  PY
  touch "$out"
''
