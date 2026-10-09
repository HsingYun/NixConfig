{ lib }:
{
  packages,
  pacman ? "/usr/bin/pacman",
  privilegeCommand,
  getent ? "/usr/bin/getent",
  systemctl ? "/usr/bin/systemctl",
}:
''
  (
    obsolete=()
    # Query the database once: a failed query must not look like an absent package.
    installed=$(${lib.escapeShellArg pacman} -Qq) || {
      echo "Native-to-Nix migration: cannot read the installed package database." >&2
      exit 1
    }
    for package in ${lib.escapeShellArgs packages}; do
      while IFS= read -r name; do
        if [[ $name == "$package" ]]; then
          obsolete+=("$package")
          break
        fi
      done <<< "$installed"
    done
    if (( ''${#obsolete[@]} > 0 )); then
      # Package dependencies do not describe login shells or enabled services.
      # Check those native entry points too before removing an application.
      accounts=$(${lib.escapeShellArg getent} passwd) || exit $?
      while IFS=: read -r account password uid gid gecos directory loginShell; do
        [[ -n $loginShell ]] || continue
        owner=$(${lib.escapeShellArg pacman} -Qqo -- "$loginShell" 2>/dev/null || true)
        for package in "''${obsolete[@]}"; do
          if [[ $owner == "$package" ]]; then
            echo "Refusing to remove $package: $loginShell is still an account's login shell. Migrate the login shell first." >&2
            exit 1
          fi
        done
      done <<< "$accounts"
      for package in "''${obsolete[@]}"; do
        files=$(${lib.escapeShellArg pacman} -Qlq -- "$package") || exit $?
        while IFS= read -r file; do
          case "$file" in
            /usr/lib/systemd/system/*.service|/usr/lib/systemd/system/*.socket|/usr/lib/systemd/system/*.timer|/usr/lib/systemd/system/*.path|/usr/lib/systemd/system/*.target|/usr/lib/systemd/system/*.mount|/usr/lib/systemd/system/*.automount|/usr/lib/systemd/system/*.swap|/usr/lib/systemd/system/*.slice)
              unit="''${file##*/}"
              # A disconnected system bus is not evidence that a unit is idle.
              state=$(${lib.escapeShellArg systemctl} show --property=ActiveState,UnitFileState -- "$unit") || {
                echo "Refusing to remove $package: cannot inspect native unit $unit." >&2
                exit 1
              }
              activeState= unitFileState=
              while IFS== read -r key value; do
                case "$key" in
                  ActiveState) activeState=$value ;;
                  UnitFileState) unitFileState=$value ;;
                esac
              done <<< "$state"
              case "$activeState" in
                inactive|failed) ;;
                *) echo "Refusing to remove $package: native unit $unit is active or has unknown state." >&2; exit 1 ;;
              esac
              case "$unitFileState" in
                disabled|masked|masked-runtime|not-found|"") ;;
                *) echo "Refusing to remove $package: native unit $unit is still enabled or linked." >&2; exit 1 ;;
              esac
              ;;
          esac
        done <<< "$files"
      done
      # Plain -R validates reverse dependencies. Never cascade, recurse, skip
      # dependency checks, or discard modified package configuration/backups.
      run ${lib.escapeShellArgs privilegeCommand} ${lib.escapeShellArg pacman} -R --noconfirm -- "''${obsolete[@]}" || {
        echo "Native-to-Nix migration was refused by pacman. Keep the native provider for packages still required by the host." >&2
        exit 1
      }
    fi
  )
''
