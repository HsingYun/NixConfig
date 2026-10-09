{ lib }:
{
  privilegeCommand,
  nixEnv,
  readlink,
  profilePath,
  packageSet,
}:
''
  if [[ $(${lib.escapeShellArg readlink} -f ${lib.escapeShellArg profilePath} || true) != ${lib.escapeShellArg packageSet} ]]; then
    run ${lib.escapeShellArgs privilegeCommand} ${lib.escapeShellArg nixEnv} --profile ${lib.escapeShellArg profilePath} --set ${lib.escapeShellArg packageSet}
  fi
  # HM generations reference this package set through their activation script.
  # This auxiliary profile roots only the currently selected system packages;
  # retaining a second history would prevent HM generation GC from releasing them.
  run ${lib.escapeShellArgs privilegeCommand} ${lib.escapeShellArg nixEnv} --profile ${lib.escapeShellArg profilePath} --delete-generations old
''
