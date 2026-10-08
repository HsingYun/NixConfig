{ inputs, pkgs }:
let
  app = import ../../apps/nixman {
    inherit pkgs;
    homeManager = inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.home-manager;
  };
in
pkgs.runCommand "nixman-check"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.nix
      pkgs.git
    ];
  }
  ''
    export PYTHONDONTWRITEBYTECODE=1
    export PYTHONPATH=${../../apps/nixman}
    python ${./test_nixman.py}
    python ${./integration.py}
    ${app}/bin/nixman --help > /dev/null
    ${app}/bin/nixman update --help > /dev/null
    ${app}/bin/nixman generation switch --help > /dev/null
    touch "$out"
  ''
