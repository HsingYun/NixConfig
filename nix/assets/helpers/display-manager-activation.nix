{ lib, pkgs }:
{
  service,
  owner ? "default",
  files ? [ ],
  cmp ? "/usr/bin/cmp",
  systemctl ? "/usr/bin/systemctl",
  sudo ? "/usr/bin/sudo",
  readlink ? "/usr/bin/readlink",
  displayManagerLink ? "/etc/systemd/system/display-manager.service",
}:
''
  (
    # A regular file or an unknown alias belongs to the administrator.
    if [[ -e ${lib.escapeShellArg displayManagerLink} && ! -L ${lib.escapeShellArg displayManagerLink} ]]; then
      echo "Refusing unmanaged display-manager file." >&2
      exit 1
    fi
    managerPath=$(${lib.escapeShellArg readlink} -f -- ${lib.escapeShellArg displayManagerLink} || true)
    previousManager="''${managerPath##*/}"
    case "$previousManager" in
      ""|display-manager.service|gdm.service|greetd.service) ;;
      *) echo "Refusing to replace an unsupported display manager: $previousManager" >&2; exit 1 ;;
    esac
    changed=0
    ${lib.concatMapStringsSep "\n" (file: ''
      if ! ${lib.escapeShellArg cmp} -s -- ${lib.escapeShellArg file.source} ${lib.escapeShellArg file.destination}; then
        changed=1
      fi
      ${import ./owned-root-file.nix { inherit lib pkgs; } (
        {
          active = true;
          inherit sudo owner;
          inherit (file) source destination;
        }
        // lib.optionalAttrs (file ? stateFile) { inherit (file) stateFile; }
      )}
    '') files}
    if [[ $changed == 1 ]]; then
      run ${lib.escapeShellArg sudo} ${lib.escapeShellArg systemctl} daemon-reload || exit $?
    fi
    # Inspect the next boot's alias, not the still-running display manager.
    managerPath=$(${lib.escapeShellArg readlink} -f -- ${lib.escapeShellArg displayManagerLink} || true)
    previousManager="''${managerPath##*/}"
    managerState=$(${lib.escapeShellArg systemctl} is-enabled ${lib.escapeShellArg service} 2>/dev/null || true)
    bootTarget=$(${lib.escapeShellArg systemctl} get-default) || exit $?

    if [[ $managerState != enabled || $previousManager != ${lib.escapeShellArg service} ]]; then
      # Enable the replacement before removing the old boot links. Deliberately
      # omit --now: changing the login screen must not end the current session.
      run ${lib.escapeShellArg sudo} ${lib.escapeShellArg systemctl} enable --force ${lib.escapeShellArg service} || exit $?
    fi
    # Recheck both supported managers even if a previous attempt changed the
    # alias and then failed before removing the other manager's boot links.
    for candidate in gdm.service greetd.service; do
      if [[ $candidate != *.service || $candidate == ${lib.escapeShellArg service} || $candidate == display-manager.service ]]; then
        continue
      fi
      candidateState=$(${lib.escapeShellArg systemctl} is-enabled "$candidate" 2>/dev/null || true)
      if [[ $candidateState == enabled || $candidateState == enabled-runtime ]]; then
        run ${lib.escapeShellArg sudo} ${lib.escapeShellArg systemctl} disable -- "$candidate" || exit $?
      fi
    done
    if [[ $bootTarget != graphical.target ]]; then
      run ${lib.escapeShellArg sudo} ${lib.escapeShellArg systemctl} set-default graphical.target || exit $?
    fi
  )
''
