{ pkgs }:
pkgs.runCommand "native-units-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  export PYTHONDONTWRITEBYTECODE=1
  python3 ${./systemd.py} ${../../../assets/helpers}/common/systemd.py
  touch "$out"
''
