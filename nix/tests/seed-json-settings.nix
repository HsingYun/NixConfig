{ pkgs }:
let
  python = pkgs.python3.withPackages (p: [ p.json5 ]);
in
pkgs.runCommand "seed-json-settings-check" { } ''
  export PYTHONDONTWRITEBYTECODE=1
  ${python}/bin/python ${./seed-json-settings.py} ${../assets/helpers}/seed-json-settings.py
  touch "$out"
''
