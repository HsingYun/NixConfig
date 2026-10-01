{ lib }:
{
  command,
  name,
  script,
  complete ? true,
}:
''
  (
    set -e
    nativeStage=${lib.escapeShellArg name}
    run ${command} stage-start --pid "$$" --worker "$BASHPID" --stage ${lib.escapeShellArg name}
    trap 'nativeStatus=$?; if (( nativeStatus != 0 )) && [[ ! -v DRY_RUN ]]; then
      ${command} failed --pid "$$" --stage "$nativeStage" --exit-code "$nativeStatus" || true
    fi' EXIT
    ${script}
    ${lib.optionalString complete ''run ${command} stage-end --pid "$$" --stage ${lib.escapeShellArg name}''}
  )
''
