{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  darwin = pkgs.stdenv.hostPlatform.isDarwin;
  # Public, non-personal test keys maintained by the pinned upstream suite.
  keys = "${inputs.home-manager}/tests/modules/programs/gpg/test-keys/multiple-keys.asc";
  check =
    { mutableKeys, mutableTrust }:
    let
      cfg =
        (inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ../../modules/home/software
            {
              home = {
                username = "gpg-test";
                homeDirectory = if darwin then "/Users/gpg-test" else "/home/gpg-test";
                stateVersion = "26.05";
              };
              software = {
                platform = if darwin then "darwin" else "arch";
                packageManager = if darwin then "homebrew" else "pacman";
              };
              programs.gpg = {
                enable = true;
                inherit mutableKeys mutableTrust;
                publicKeys = [
                  {
                    source = keys;
                    trust = "full";
                  }
                ];
              };
            }
          ];
        }).config;
      # Retain context so Nix builds HM's actual keyring derivation. Evaluating
      # an activation drvPath alone would miss its absent build dependencies.
      activation = pkgs.writeText "gpg-import-keys" cfg.home.activation.importGpgKeys.data;
    in
    assert cfg.software.resolved.gnupg.provider == "nix";
    ''
      export GNUPGHOME=$(mktemp -d)
      chmod 700 "$GNUPGHOME"
      ${lib.optionalString (!mutableKeys) ''
        test -s ${cfg.home.file."${cfg.programs.gpg.homedir}/pubring.kbx".source}
      ''}
      ${lib.optionalString (!mutableTrust) ''
        trustdb=$(grep -o '/nix/store/[^ ]*/trustdb.gpg' ${activation})
        test -s "$trustdb"
        cp "$trustdb" "$GNUPGHOME/trustdb.gpg"
        gpg --export-ownertrust > trust.txt
        test "$(grep -c ':5:$' trust.txt)" = 3
      ''}
      rm -rf "$GNUPGHOME"
    '';
in
pkgs.runCommand "gpg-build-demand"
  {
    nativeBuildInputs = [
      pkgs.gnupg
      pkgs.gnugrep
    ];
  }
  (
    lib.concatMapStringsSep "\n" check [
      {
        mutableKeys = false;
        mutableTrust = true;
      }
      {
        mutableKeys = true;
        mutableTrust = false;
      }
      {
        mutableKeys = false;
        mutableTrust = false;
      }
    ]
    + "\ntouch $out\n"
  )
