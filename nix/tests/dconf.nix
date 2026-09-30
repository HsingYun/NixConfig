{ inputs, pkgs }:
let
  # Generate the state through the pinned upstream module, so format changes
  # cannot silently leave a fixture-only test green.
  generation =
    settings: databases:
    let
      home =
        (inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            {
              home = {
                username = "test";
                homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/test" else "/home/test";
                stateVersion = "26.05";
              };
              dconf = {
                enable = true;
                inherit settings databases;
              };
            }
          ];
        }).config;
    in
    pkgs.runCommand "upstream-dconf-generation" { } (
      "mkdir -p $out\n" + home.home.extraBuilderCommands
    );
  old = generation { "org/gnome/terminal/legacy/profiles:/:test".visible-name = "Test"; } {
    secondary.example.value = true;
    kept.example.retained = true;
  };
  new = generation { } { kept.example.retained = true; };
  empty = generation { } { };
  # Exercise generation transitions without a graphical session, including on
  # macOS CI. The recorder substitutes only the dconf/DBus process boundary.
  recorder = pkgs.writeShellScriptBin "dconf" ''
    profile=default
    if [[ -n ''${DCONF_PROFILE:-} ]]; then
      profile=$(cat "$DCONF_PROFILE")
    fi
    printf '%s %s %s\n' "$profile" "$1" "$2" >> "$DCONF_TEST_LOG"
    [[ ''${DCONF_TEST_FAIL:-0} == 0 ]]
  '';
  dbus = pkgs.writeShellScriptBin "dbus-run-session" ''
    shift
    exec "$@"
  '';
  cleanup = import ../assets/helpers/dconf-removed-databases.nix {
    pkgs = pkgs // {
      dconf = recorder;
      inherit dbus;
    };
  };
in
pkgs.runCommand "dconf-removed-databases-check" { } ''
  export DCONF_TEST_LOG="$TMPDIR/commands"
  touch "$DCONF_TEST_LOG"
  ln -s ${old} old
  ln -s ${new} new
  ln -s ${empty} empty
  # A stale inherited profile must not redirect the default database cleanup.
  echo user-db:wrong > inherited-profile
  export DCONF_PROFILE="$PWD/inherited-profile" DBUS_SESSION_BUS_ADDRESS=test
  ${cleanup}/bin/dconf-removed-databases "$PWD/old" "$PWD/new"
  cat > expected <<'TEXT'
  default reset /org/gnome/terminal/legacy/profiles:/:test/visible-name
  user-db:secondary reset /example/value
  TEXT
  # Glob ordering is not part of the contract.
  sort "$DCONF_TEST_LOG" > actual
  sort expected > wanted
  cmp actual wanted
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
  touch "$out"
''
