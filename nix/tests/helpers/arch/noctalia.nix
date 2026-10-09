{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  inherit (import ../../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  make =
    extra:
    (mkHost "NoctaliaValidation" {
      platform = "arch";
      features = allOff;
      homeConfig = {
        imports = [ extra ];
        home.stateVersion = "26.05";
        xdg.configHome = "/home/test/config dir";
        programs.noctalia = {
          enable = true;
          settings.theme.mode = "dark";
        };
      };
    }).views.home;
  normal = make { };
  disabled = make { xdg.configFile."noctalia/config.toml".enable = false; };
  finalDisabled = make (
    { config, lib, ... }: {
      home.file."${config.xdg.configHome}/noctalia/config.toml".enable = lib.mkForce false;
    }
  );
  finalReenabled = make (
    { config, lib, ... }: {
      xdg.configFile."noctalia/config.toml".enable = false;
      home.file."${config.xdg.configHome}/noctalia/config.toml".enable = lib.mkForce true;
    }
  );
  unchecked = make { programs.noctalia.checkConfig = false; };
  sourceOverride =
    source:
    make (
      { config, lib, ... }: {
        home.file."${config.xdg.configHome}/noctalia/config.toml".source = lib.mkForce source;
      }
    );
  candidate = pkgs.writeText "candidate.toml" (builtins.readFile ./noctalia-valid.toml);
  invalidCandidate = pkgs.writeText "invalid-candidate.toml" "invalid";
  finalSource = sourceOverride candidate;
  localSource = sourceOverride ./noctalia-valid.toml;
  localStringSource = sourceOverride (toString ./noctalia-valid.toml);
  invalidSource = sourceOverride invalidCandidate;
  validation = home: home.home.activation.validateArchNoctalia;
  fakeNoctalia = pkgs.writeShellScript "noctalia" ''
    set -e
    test "$#" = 3
    test "$1" = config
    test "$2" = validate
    cmp "$3" ${candidate}
  '';
  candidateCheck =
    home:
    pkgs.writeShellScript "validate-candidate" (
      "run() { \"$@\"; }\n"
      + lib.replaceStrings [ "/usr/bin/noctalia" ] [ (toString fakeNoctalia) ] (validation home).data
    );
in
assert lib.all (home: lib.all (a: a.assertion) home.assertions) [
  normal
  disabled
  finalDisabled
  finalReenabled
  unchecked
  finalSource
  localSource
  localStringSource
  invalidSource
];
assert lib.all (home: !(home.home.activation ? validateArchNoctalia)) [
  disabled
  finalDisabled
  unchecked
];
assert finalReenabled.home.activation ? validateArchNoctalia;
assert lib.hasInfix (builtins.unsafeDiscardStringContext (
  toString candidate
)) (validation finalSource).data;
assert lib.hasInfix (builtins.unsafeDiscardStringContext (
  toString invalidCandidate
)) (validation invalidSource).data;
# Plain local paths are copied before activation, just like the deployed HM file.
assert
  !(lib.hasInfix (builtins.unsafeDiscardStringContext (toString ./noctalia-valid.toml)) (validation localStringSource)
  .data);
assert (validation localSource).data == (validation localStringSource).data;
assert builtins.elem "installNativePackages" (validation normal).after;
assert builtins.elem "linkGeneration" (validation normal).before;
pkgs.runCommand "native-noctalia-config-check" { } ''
  ${candidateCheck finalSource}
  ${candidateCheck localSource}
  ${candidateCheck localStringSource}
  if ${candidateCheck invalidSource}; then
    echo "Invalid replacement Noctalia configuration was accepted" >&2; exit 1
  fi
  touch "$out"
''
