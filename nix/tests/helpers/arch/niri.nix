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
  finalDisabled = make (
    { config, lib, ... }: {
      home.file."${config.xdg.configHome}/niri/config.kdl".enable = lib.mkForce false;
    }
  );
  finalReenabled = make (
    { config, lib, ... }: {
      xdg.configFile."niri/config.kdl".enable = false;
      home.file."${config.xdg.configHome}/niri/config.kdl".enable = lib.mkForce true;
    }
  );
  finalMoved = make (
    { config, lib, ... }: {
      home.file."${config.xdg.configHome}/niri/config.kdl".target = lib.mkForce "final dir/custom.kdl";
    }
  );
  withoutXdg = make { xdg.enable = false; };
  sourceOverride =
    source:
    make (
      { config, lib, ... }: {
        home.file."${config.xdg.configHome}/niri/config.kdl".source = lib.mkForce source;
      }
    );
  candidate = pkgs.writeText "candidate.kdl" "// valid";
  invalidCandidate = pkgs.writeText "invalid-candidate.kdl" "invalid";
  finalSource = sourceOverride candidate;
  localSource = sourceOverride ./niri-valid.kdl;
  localStringSource = sourceOverride (toString ./niri-valid.kdl);
  invalidSource = sourceOverride invalidCandidate;
  resource = host: host.system.native.resources.niri-config;
  fakeNiri = pkgs.writeShellScript "niri" ''
    set -e
    test "$1" = validate
    test "$2" = --config
    test "$#" = 3
    test "$(cat "$3")" = "// valid"
  '';
  candidateCheck =
    host:
    pkgs.writeShellScript "validate-candidate" (
      "run() { \"$@\"; }\n"
      +
        lib.replaceStrings [ "/usr/bin/niri" ] [ (toString fakeNiri) ]
          host.system.native.activation.validateNiriConfig.data
    );
  runLive = pkgs.writeShellScript "validate-live" (
    lib.replaceStrings
      [ "/usr/bin/niri" (resource finalMoved).desired.target ]
      [ (toString fakeNiri) "live dir/custom.kdl" ]
      (resource finalMoved).check
  );
in
assert (resource normal).desired.target == "/home/test/config dir/niri/config.kdl";
assert (resource moved).desired.target == "/home/test/other dir/custom.kdl";
assert (resource finalMoved).desired.target == "/home/test/final dir/custom.kdl";
assert toString (resource finalSource).desired.source == toString candidate;
assert toString (resource invalidSource).desired.source == toString invalidCandidate;
# Candidate validation must depend on the immutable source, including string paths.
assert builtins.hasContext (resource localSource).desired.source;
assert builtins.hasContext (resource localStringSource).desired.source;
assert (resource localSource).desired.source == (resource localStringSource).desired.source;
assert (resource localSource).desired.source != toString ./niri-valid.kdl;
assert lib.all (host: lib.all (a: a.assertion) host.home.assertions) [
  normal
  moved
  disabled
  finalDisabled
  finalReenabled
  finalMoved
  finalSource
  localSource
  localStringSource
  invalidSource
  withoutXdg
];
assert lib.all (
  host:
  !(host.system.native.resources ? niri-config)
  && !(host.system.native.activation ? validateNiriConfig)
) [ finalDisabled ];
assert (resource finalReenabled).desired.target == (resource normal).desired.target;
# Disabling XDG environment variables does not disable managed files in HM.
assert (resource withoutXdg).desired.target == (resource normal).desired.target;
assert !(disabled.system.native.resources ? niri-config);
assert !(disabled.system.native.activation ? validateNiriConfig);
assert builtins.elem "installNativePackages" normal.home.home.activation.validateNiriConfig.after;
assert builtins.elem "linkGeneration" normal.home.home.activation.validateNiriConfig.before;
pkgs.runCommand "native-niri-config-check" { } ''
  ${candidateCheck finalSource}
  ${candidateCheck localSource}
  ${candidateCheck localStringSource}
  if ${candidateCheck invalidSource}; then
    echo "Invalid candidate source override was accepted" >&2; exit 1
  fi
  mkdir 'live dir'
  echo '// valid' > 'live dir/custom.kdl'
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
