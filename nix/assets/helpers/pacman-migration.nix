{ lib }:
{
  packages,
  pacman ? "/usr/bin/pacman",
  sudo ? "/usr/bin/sudo",
  getent ? "/usr/bin/getent",
  systemctl ? "/usr/bin/systemctl",
}:
''
  (
    obsolete=()
    for package in ${lib.escapeShellArgs packages}; do
      if ${lib.escapeShellArg pacman} -Q -- "$package" >/dev/null 2>&1; then
        obsolete+=("$package")
      fi
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
            /usr/lib/systemd/system/*.service|/usr/lib/systemd/system/*.socket|/usr/lib/systemd/system/*.timer)
              unit="''${file##*/}"
              if ${lib.escapeShellArg systemctl} is-active --quiet "$unit" ||
                 ${lib.escapeShellArg systemctl} is-enabled --quiet "$unit"; then
                echo "Refusing to remove $package: native unit $unit is still in use." >&2
                exit 1
              fi
              ;;
          esac
        done <<< "$files"
      done
      # Plain -R validates reverse dependencies. Never cascade, recurse, skip
      # dependency checks, or discard modified package configuration/backups.
      run ${lib.escapeShellArg sudo} ${lib.escapeShellArg pacman} -R --noconfirm -- "''${obsolete[@]}" || {
        echo "Native-to-Nix migration was refused by pacman. Keep the native provider for packages still required by the host." >&2
        exit 1
      }
    fi
  )
''
