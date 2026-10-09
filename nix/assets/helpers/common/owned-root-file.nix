{ lib, pkgs }:
{
  active,
  owner ? "default",
  text ? "",
  source ? pkgs.writeText "managed-system-file" text,
  destination,
  stateFile ? "/var/lib/nixconfig/files/${builtins.hashString "sha256" destination}.json",
  privilegeCommand,
}:
''
  # Root state is authoritative; user-controlled hashes cannot grant ownership.
  if ${if active then "true" else "false"} || [[ -e ${lib.escapeShellArg stateFile} ]]; then
    run ${lib.escapeShellArgs privilegeCommand} ${pkgs.python3}/bin/python3 ${./.}/owned-file.py \
      ${lib.escapeShellArg destination} ${lib.escapeShellArg stateFile} \
      ${
        lib.escapeShellArg (if active then toString source else "")
      } ${lib.escapeShellArg owner} || exit $?
  fi
''
