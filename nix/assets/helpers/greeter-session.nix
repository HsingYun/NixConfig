{ lib, pkgs }:
{
  command,
  cacheDir,
  desktop,
}:
pkgs.writeShellScriptBin "dms-greeter" ''
  set -eu
  ${pkgs.python3}/bin/python3 ${./.}/greeter-session.py ${lib.escapeShellArg cacheDir} ${lib.escapeShellArg desktop}
  exec ${lib.escapeShellArg command} --remember-last-session true "$@"
''
