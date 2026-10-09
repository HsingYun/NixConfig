{ lib, pkgs }:
{
  service,
  owner ? "default",
  files ? [ ],
  systemctl ? "/usr/bin/systemctl",
  privilegeCommand,
  stateFile ? "/var/lib/nixconfig/display-manager/state.json",
  displayManagerLink ? "/etc/systemd/system/display-manager.service",
}:
let
  manifest = pkgs.writeText "display-manager-files.json" (builtins.toJSON files);
in
''
  if ${if service != null then "true" else "test -f ${lib.escapeShellArg stateFile}"}; then
    run ${lib.escapeShellArgs privilegeCommand} ${pkgs.python3}/bin/python3 ${../.}/arch/display-manager.py \
      --owner ${lib.escapeShellArg owner} --state ${lib.escapeShellArg stateFile} \
      --service ${lib.escapeShellArg (if service == null then "" else service)} \
      --files ${manifest} --systemctl ${lib.escapeShellArg systemctl} \
      --alias ${lib.escapeShellArg displayManagerLink} || exit $?
  fi
''
