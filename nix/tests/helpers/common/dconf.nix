{ inputs, pkgs }:
let
  # Generate the state through the pinned upstream module, so format changes
  # cannot silently leave a fixture-only test green.
  home =
    settings: databases:

    (inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = testPkgs;
      modules = [
        ../../../modules/home/shared/dconf.nix
        {
          home = {
            username = "test";
            homeDirectory = "/home/test";
            stateVersion = "26.05";
          };
          dconf = {
            enable = true;
            inherit settings databases;
          };
        }
      ];
    }).config;
  generationFor =
    config:
    pkgs.runCommand "upstream-dconf-generation" { } (
      "mkdir -p $out\n" + config.home.extraBuilderCommands
    );
  generation = settings: databases: generationFor (home settings databases);
  old = generation { "org/gnome/terminal/legacy/profiles:/:test".visible-name = "Test"; } {
    secondary.example.value = true;
    kept.example.retained = true;
  };
  new = generation { } { kept.example.retained = true; };
  empty = generation { } { };
  # Exercise generation transitions without a graphical session. The recorder
  # substitutes only the dconf/DBus process boundary.
  recorder = pkgs.writeShellScriptBin "dconf" ''
    profile=default
    if [[ -n ''${DCONF_PROFILE:-} ]]; then
      profile=$(cat "$DCONF_PROFILE")
    fi
    printf '%s %s %s\n' "$profile" "$1" "$2" >> "$DCONF_TEST_LOG"
    [[ ''${DCONF_TEST_FAIL:-0} == 0 ]] || exit 1
    if [[ $1 == load ]]; then
      cat > "$DCONF_TEST_VALUE"
    elif [[ -n ''${DCONF_TEST_VALUE:-} ]]; then
      echo reset > "$DCONF_TEST_VALUE"
    fi
  '';
  dbus = pkgs.writeShellScriptBin "dbus-run-session" ''
    shift
    exec "$@"
  '';
  testPkgs = pkgs.extend (
    _: _: {
      dconf = recorder;
      inherit dbus;
    }
  );
  cleanup = import ../../../assets/helpers/common/dconf-removed-databases.nix { pkgs = testPkgs; };
  defaultDatabase = home { example.value = true; } { };
  namedDatabase = home { } { user.example.value = true; };
  transition =
    from: to:
    let
      # Sort the actual upstream DAG; running helpers in a handcrafted order
      # would miss a regression in the module's activation dependencies.
      nodes = pkgs.lib.filterAttrs (
        name: _:
        builtins.elem name [
          "dconfRemovedDatabases"
          "dconfSettings"
        ]
      ) to.home.activation;
      ordered = inputs.home-manager.lib.hm.dag.topoSort nodes;
    in
    pkgs.writeShellScript "dconf-transition" (
      ''
        set -euo pipefail
        run() { "$@"; }
        export oldGenPath=${generationFor from} newGenPath=${generationFor to}
      ''
      + pkgs.lib.concatMapStringsSep "\n" (node: node.data) ordered.result
    );
in
pkgs.runCommand "dconf-removed-databases-check" { } ''
  export DCONF_TEST_LOG="$TMPDIR/commands"
  touch "$DCONF_TEST_LOG"
  ln -s ${old} old
  ln -s ${new} new
  ln -s ${empty} empty
  unset DCONF_PROFILE
  export DBUS_SESSION_BUS_ADDRESS=test
  ${cleanup}/bin/dconf-removed-databases "$PWD/old" "$PWD/new"
  cat > expected <<'TEXT'
  default reset /org/gnome/terminal/legacy/profiles:/:test/visible-name
  user-db:secondary reset /example/value
  TEXT
  # Glob ordering is not part of the contract.
  sort "$DCONF_TEST_LOG" > actual
  sort expected > wanted
  cmp actual wanted
  # A custom runtime profile is not recorded in the old manifest. Do not
  # guess its identity or redirect cleanup into the default database.
  echo user-db:custom > inherited-profile
  export DCONF_PROFILE="$PWD/inherited-profile"
  : > "$DCONF_TEST_LOG"
  ${cleanup}/bin/dconf-removed-databases "$PWD/old" "$PWD/new"
  test "$(cat "$DCONF_TEST_LOG")" = 'user-db:secondary reset /example/value'
  unset DCONF_PROFILE
  # Empty new generation, absent old generation, and a GC'd manifest.
  : > "$DCONF_TEST_LOG"
  unset DBUS_SESSION_BUS_ADDRESS
  ${cleanup}/bin/dconf-removed-databases "$PWD/new" "$PWD/empty"
  test "$(cat "$DCONF_TEST_LOG")" = 'user-db:kept reset /example/retained'
  : > "$DCONF_TEST_LOG"
  ${cleanup}/bin/dconf-removed-databases "" "$PWD/new"
  ${cleanup}/bin/dconf-removed-databases "$PWD/missing" "$PWD/new"
  mkdir -p collected/state
  ln -s "$PWD/missing.json" collected/state/dconf-keys.json
  ${cleanup}/bin/dconf-removed-databases "$PWD/collected" "$PWD/new"
  test ! -s "$DCONF_TEST_LOG"
  # Present databases are exclusively upstream-owned; unchanged is a no-op.
  ${cleanup}/bin/dconf-removed-databases "$PWD/old" "$PWD/old"
  test ! -s "$DCONF_TEST_LOG"
  if DCONF_TEST_FAIL=1 ${cleanup}/bin/dconf-removed-databases "$PWD/new" "$PWD/empty"; then
    echo 'dconf failure was suppressed' >&2
    exit 1
  fi
  # Both spellings address user-db:user. New values must survive migration
  # in either direction; use upstream-generated manifests and load commands.
  export DCONF_TEST_VALUE="$TMPDIR/value" DBUS_SESSION_BUS_ADDRESS=test
  for activate in ${transition defaultDatabase namedDatabase} ${transition namedDatabase defaultDatabase}; do
    : > "$DCONF_TEST_LOG"
    echo previous > "$DCONF_TEST_VALUE"
    "$activate"
    grep -Fx 'value=true' "$DCONF_TEST_VALUE"
    test "$(head -n1 "$DCONF_TEST_LOG" | cut -d' ' -f2)" = reset
    test "$(tail -n1 "$DCONF_TEST_LOG" | cut -d' ' -f2)" = load
  done
  touch "$out"
''
