{ pkgs }:
pkgs.runCommand "network-preflight-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  export PYTHONDONTWRITEBYTECODE=1
  python3 ${./network-preflight.py} ${../../../assets/helpers}/arch/network-preflight.py
  touch "$out"
''
