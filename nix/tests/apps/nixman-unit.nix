{ pkgs }:
pkgs.runCommand "nixman-unit-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  export PYTHONDONTWRITEBYTECODE=1
  export PYTHONPATH=${../../apps/nixman}
  python ${./test_nixman.py}
  python ${./test_interface.py}
  python ${./test_terminal.py}
  touch "$out"
''
