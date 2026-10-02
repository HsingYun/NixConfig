{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  inherit (import ../../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  make =
    extra:
    (mkHost "NiriValidation" {
      platform = "arch";
      features.niri = true;
      homeConfig = {
        imports = [ extra ];
        home.stateVersion = "26.05";
        xdg.configHome = "/home/test/config dir";
      };
    }).views;
  normal = make { };
  moved = make { xdg.configFile."niri/config.kdl".target = "/home/test/other dir/custom.kdl"; };
  disabled = make { xdg.configFile."niri/config.kdl".enable = false; };
  resource = host: host.system.native.resources.niri-config;
  fakeNiri = pkgs.writeShellScript "niri" ''
    set -e
    test "$1" = validate
    test "$2" = --config
    test "$#" = 3
    test "$(cat "$3")" = valid
  '';
  candidate = pkgs.writeText "candidate.kdl" "valid";
  runCandidate = pkgs.writeShellScript "validate-candidate" (
    "run() { \"$@\"; }\n"
    +
      lib.replaceStrings
        [ "/usr/bin/niri" (resource moved).desired.source ]
        [ (toString fakeNiri) (toString candidate) ]
        moved.system.native.activation.validateNiriConfig.data
  );
  runLive = pkgs.writeShellScript "validate-live" (
    lib.replaceStrings
      [ "/usr/bin/niri" (resource moved).desired.target ]
      [ (toString fakeNiri) "live dir/custom.kdl" ]
      (resource moved).check
  );
in
assert (resource normal).desired.target == "/home/test/config dir/niri/config.kdl";
assert (resource moved).desired.target == "/home/test/other dir/custom.kdl";
assert !(disabled.system.native.resources ? niri-config);
assert !(disabled.system.native.activation ? validateNiriConfig);
assert builtins.elem "installNativePackages" normal.home.home.activation.validateNiriConfig.after;
assert builtins.elem "linkGeneration" normal.home.home.activation.validateNiriConfig.before;
pkgs.runCommand "native-niri-config-check" { } ''
  ${runCandidate}
  mkdir 'live dir'
  echo valid > 'live dir/custom.kdl'
  ${runLive}
  echo invalid > 'live dir/custom.kdl'
  if ${runLive}; then
    echo "Invalid deployed config was accepted" >&2; exit 1
  fi
  rm 'live dir/custom.kdl'
  if ${runLive}; then
    echo "Missing deployed config was accepted" >&2; exit 1
  fi
  touch "$out"
''
