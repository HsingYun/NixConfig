{ pkgs }:
pkgs.runCommand "native-launcher-check" { } ''
  ${pkgs.python3}/bin/python ${./launcher-native.py} ${../../../assets/helpers}/arch/launcher.py \
    ${pkgs.desktop-file-utils}/bin/desktop-file-install
  touch "$out"
''
