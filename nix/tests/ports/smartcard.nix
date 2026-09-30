{ lib, mkHost }:
let
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  cases = [
    {
      name = "darwin-smartcard-with-gpg";
      features = {
        smartcard = true;
        gpg = true;
      };
      expected = true;
    }
    {
      name = "darwin-smartcard-disabled";
      features.gpg = true;
      expected = null;
    }
    {
      name = "darwin-smartcard-without-gpg";
      features.smartcard = true;
      expected = null;
    }
    {
      name = "darwin-smartcard-with-external-gpg";
      features.smartcard = true;
      homeConfig.programs.gpg.enable = true;
      expected = true;
    }
    {
      name = "darwin-smartcard-with-disabled-gpg-module";
      features = {
        smartcard = true;
        gpg = true;
      };
      homeConfig.programs.gpg.enable = false;
      expected = null;
    }
    {
      name = "darwin-smartcard-local-override";
      features = {
        smartcard = true;
        gpg = true;
      };
      homeConfig.programs.gpg.scdaemonSettings.disable-ccid = false;
      expected = false;
    }
  ];
  verify =
    case:
    let
      cfg =
        (mkHost "SmartcardTest" {
          platform = "darwin";
          features = allOff // case.features;
          systemConfig.system.stateVersion = 6;
          homeConfig = {
            imports = [ (case.homeConfig or { }) ];
            home.stateVersion = "26.05";
          };
        }).configuration.config;
      home = cfg.home-manager.users.test;
      settings = home.programs.gpg.scdaemonSettings;
      scdaemonConfig = "${home.programs.gpg.homedir}/scdaemon.conf";
    in
    assert lib.assertMsg (lib.all (a: a.assertion) (
      cfg.assertions ++ home.assertions
    )) "Smartcard module assertion failed: ${case.name}";
    assert !(cfg.services ? pcscd);
    assert !(settings ? pcsc-driver);
    assert lib.assertMsg (
      (settings.disable-ccid or null) == case.expected
    ) "Unexpected Darwin smartcard settings: ${case.name}";
    assert (home.home.file ? ${scdaemonConfig}) == (case.expected != null);
    assert case.expected != true || lib.hasInfix "disable-ccid" home.home.file.${scdaemonConfig}.text;
    case.name;
in
map verify cases
