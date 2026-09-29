{ lib }:
{
  packages,
  aur,
  pacman ? "/usr/bin/pacman",
  yay ? "/usr/bin/yay",
  sudo ? "/usr/bin/sudo",
}:
# A subshell keeps Arch build tools available without changing the rest of HM's PATH.
''
  (
    export PATH="/usr/bin:$PATH"
    repoTargets=(${lib.escapeShellArgs packages})
    aurTargets=(${lib.escapeShellArgs aur})
    if [[ ! -v DRY_RUN ]]; then
      if [[ ! -x ${lib.escapeShellArg pacman} ]]; then
        echo "Software: pacman is required for the selected backend." >&2
        exit 1
      fi
      missingRepo=()
      missingAur=()
      for target in "''${repoTargets[@]}"; do
        if ! ${lib.escapeShellArg pacman} -Q -- "$target" >/dev/null 2>&1; then
          missingRepo+=("$target")
        fi
      done
      for target in "''${aurTargets[@]}"; do
        if ! ${lib.escapeShellArg pacman} -Q -- "$target" >/dev/null 2>&1; then
          missingAur+=("$target")
        fi
      done
      repoTargets=("''${missingRepo[@]}")
      aurTargets=("''${missingAur[@]}")
      # Validate all prerequisites before the first installation.
      if (( ''${#aurTargets[@]} > 0 )); then
        if (( EUID == 0 )); then
          echo "Software: AUR builds must run as the Home Manager user, not root." >&2
          exit 1
        fi
        if [[ ! -x ${lib.escapeShellArg yay} ]]; then
          echo "Software: install yay first; AUR packages require ${yay}." >&2
          exit 1
        fi
      fi
      if (( ''${#repoTargets[@]} + ''${#aurTargets[@]} > 0 )) && [[ ! -x ${lib.escapeShellArg sudo} ]]; then
        echo "Software: sudo is required to install native packages." >&2
        exit 1
      fi
    fi
    if (( ''${#repoTargets[@]} > 0 )); then
      run ${lib.escapeShellArg sudo} ${lib.escapeShellArg pacman} -S --needed -- "''${repoTargets[@]}" || exit $?
    fi
    if (( ''${#aurTargets[@]} > 0 )); then
      run ${lib.escapeShellArg yay} -S --needed --aur -- "''${aurTargets[@]}" || exit $?
    fi
  )
''
