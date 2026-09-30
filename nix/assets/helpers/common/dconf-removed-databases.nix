{ pkgs }:
# HM already reconciles keys in databases present in both generations. Only
# handle databases whose upstream key manifest disappears from the new one.
pkgs.writeShellApplication {
  name = "dconf-removed-databases";
  runtimeInputs = [
    pkgs.jq
    pkgs.dconf
    pkgs.dbus
  ];
  text = ''
    oldGeneration=$1
    newGeneration=$2
    [[ -n "$oldGeneration" ]] || exit 0
    temporary=$(mktemp -d)
    trap 'rm -rf "$temporary"' EXIT
    for oldKeys in "$oldGeneration"/state/dconf-keys*.json; do
      [[ -f "$oldKeys" ]] || continue
      filename=''${oldKeys##*/}
      [[ ! -e "$newGeneration/state/$filename" ]] || continue
      case "$filename" in
        dconf-keys.json)
          # The old manifest does not record its runtime profile. With a custom
          # profile we cannot identify that database safely; leave it alone.
          if [[ -n ''${DCONF_PROFILE:-} ]]; then
            echo "Skipping removed default dconf database: DCONF_PROFILE is set." >&2
            continue
          fi
          profile=(env -u DCONF_PROFILE) ;;
        dconf-keys-*.json)
          database=''${filename#dconf-keys-}
          database=''${database%.json}
          printf 'user-db:%s\n' "$database" > "$temporary/profile"
          profile=(env "DCONF_PROFILE=$temporary/profile") ;;
        *) continue ;;
      esac
      session=()
      if [[ ! -v DBUS_SESSION_BUS_ADDRESS ]]; then
        session=(${pkgs.dbus}/bin/dbus-run-session --dbus-daemon=${pkgs.dbus}/bin/dbus-daemon)
      fi
      jq -r '.[]' "$oldKeys" | while IFS= read -r key; do
        "''${session[@]}" "''${profile[@]}" dconf reset "$key"
      done
    done
  '';
}
