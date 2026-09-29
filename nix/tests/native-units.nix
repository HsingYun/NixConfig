{ pkgs }:
pkgs.runCommand "native-units-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  export PYTHONDONTWRITEBYTECODE=1
  python3 ${./native-systemd.py} ${../assets/helpers}/native-systemd.py
  python3 ${./network-preflight.py} ${../assets/helpers}/network-preflight.py
  touch "$out"
''
