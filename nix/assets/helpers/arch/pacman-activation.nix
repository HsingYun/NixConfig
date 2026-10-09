{ lib, pkgs }:
{
  packages,
  aur,
  pacman ? "/usr/bin/pacman",
  yay ? "/usr/bin/yay",
  privilegeCommand,
}:
let
  # yay accepts one executable and whitespace-split flags. A wrapper preserves
  # the port's complete argument vector without lossy string serialization.
  elevate = pkgs.writeShellScript "native-package-elevate" ''
    exec ${lib.escapeShellArgs privilegeCommand} "$@"
  '';
in
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
      installed=$(${lib.escapeShellArg pacman} -Qq) || {
        echo "Software: cannot read the installed package database." >&2
        exit 1
      }
      declare -A present=()
      while IFS= read -r package; do
        [[ -z $package ]] || present["$package"]=1
      done <<< "$installed"
      for target in "''${repoTargets[@]}"; do
        if [[ ! -v present["$target"] ]]; then
          missingRepo+=("$target")
        fi
      done
      for target in "''${aurTargets[@]}"; do
        if [[ ! -v present["$target"] ]]; then
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
      if (( ''${#repoTargets[@]} + ''${#aurTargets[@]} > 0 )) && ! command -v ${lib.escapeShellArg (builtins.head privilegeCommand)} >/dev/null 2>&1; then
        echo "Software: the configured privilege command is required to install native packages." >&2
        exit 1
      fi
    fi
    if (( ''${#repoTargets[@]} > 0 )); then
      run ${lib.escapeShellArgs privilegeCommand} ${lib.escapeShellArg pacman} -S --needed -- "''${repoTargets[@]}" || exit $?
    fi
    if (( ''${#aurTargets[@]} > 0 )); then
      run ${lib.escapeShellArg yay} --sudo ${elevate} --sudoflags "" -S --needed --aur -- "''${aurTargets[@]}" || exit $?
    fi
  )
''
