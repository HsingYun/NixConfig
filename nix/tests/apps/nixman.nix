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
      pkgs.bash
      pkgs.zsh
      pkgs.fish
    ];
  }
  ''
    export PYTHONDONTWRITEBYTECODE=1
    export PYTHONPATH=${../../apps/nixman}
    python ${./test_nixman.py}
    python ${./test_interface.py}
    python ${./integration.py}
    export XDG_CACHE_HOME="$TMPDIR/cache"
    export XDG_CONFIG_HOME="$TMPDIR/config"
    python ${./completions.py} ${app}
    ${app}/bin/nixman --help > /dev/null
    ${app}/bin/nixman update --help > /dev/null
    ${app}/bin/nixman generation switch --help > /dev/null
    touch "$out"
  ''
