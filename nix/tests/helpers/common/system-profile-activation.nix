{ pkgs }:
let
  template = pkgs.writeText "system-profile-activation" ''
    set -euo pipefail
    run() { if [[ -v DRY_RUN ]]; then printf '%s\n' "$*"; else "$@"; fi; }
    ${import ../../../assets/helpers/common/system-profile-activation.nix { inherit (pkgs) lib; } {
      privilegeCommand = [ "env" ];
      nixEnv = "${pkgs.nix}/bin/nix-env";
      readlink = "${pkgs.coreutils}/bin/readlink";
      profilePath = "@PROFILE@";
      packageSet = "@PACKAGE_SET@";
    }}
  '';
in
pkgs.runCommand "native-system-profile-lifecycle"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.nix
      pkgs.bash
    ];
  }
  ''
    python3 ${./system-profile-activation.py} ${template}
    touch "$out"
  ''
