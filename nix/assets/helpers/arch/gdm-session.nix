{ lib, pkgs }:
{
  session,
  setSession,
  dataDirs ? [
    "/usr/local/share"
    "/usr/share"
  ],
}:
pkgs.writeShellScript "gdm-default-session" ''
  set -eu
  # The upstream AccountsService utility discovers sessions through GLib.
  # Use the same native data roots for validation and for the actual selection.
  export XDG_DATA_DIRS=${lib.escapeShellArg (lib.concatStringsSep ":" dataDirs)}
  found=false
  for root in ${lib.escapeShellArgs dataDirs}; do
    for kind in wayland-sessions xsessions; do
      if [[ -f "$root/$kind/"${lib.escapeShellArg "${session}.desktop"} ]]; then
        found=true
      fi
    done
  done
  if [[ $found != true ]]; then
    printf 'GDM default session not installed: %s\n' ${lib.escapeShellArg session} >&2
    exit 1
  fi
  if [[ ''${1-} == --check ]]; then exit 0; fi
  exec ${lib.escapeShellArg setSession} ${lib.escapeShellArg session}
''
