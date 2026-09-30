{ pkgs }:
pkgs.runCommand "display-manager-lifecycle" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  python ${./display-manager-lifecycle.py} ${../../../assets/helpers}/arch
  touch "$out"
''
