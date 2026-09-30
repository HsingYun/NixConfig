{ pkgs }:
pkgs.runCommand "architecture-boundaries" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  python ${./boundaries.py} ${../..}
  touch "$out"
''
