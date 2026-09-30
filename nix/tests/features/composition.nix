{ inputs }:

let
  inherit (inputs.nixpkgs) lib;
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost rawMkHost;
  build =
    case:
    (mkHost "FeatureTest" {
      platform = "nixos";
      features = case.features;
      featureConfig = case.featureConfig or { };
      preferences = case.preferences or { };
      hardwareConfig = {
        boot.initrd.enable = false;
        boot.kernel.enable = false;
        boot.loader.grub.enable = false;
      };
      systemConfig = {
        imports = [ (case.systemConfig or { }) ];
        system.stateVersion = "26.11";
      };
      homeConfig = {
        imports = [ (case.homeConfig or { }) ];
        home.stateVersion = "26.05";
      };
    }).configuration.config;
  cases = import ./session-cases.nix { inherit lib; };
  conflictCases = import ./conflict-cases.nix { inherit lib; };
  externalCases = import ./override-cases.nix { inherit lib allOff; };
  verify =
    case:
    let
      cfg = build case;
      home = cfg.home-manager.users.test;
      chinese = case.features.chinese or false;
      gnome = case.features.gnome or false;
      gpg = case.gpg or true;
      ssh = case.ssh or true;
      smartcard = case.features.smartcard or true;
    in
    assert lib.assertMsg (lib.all (a: a.assertion) cfg.assertions)
      "System assertion failed: ${case.name}\n${
        lib.concatMapStringsSep "\n" (a: a.message) (lib.filter (a: !a.assertion) cfg.assertions)
      }";
    assert lib.assertMsg (lib.all (a: a.assertion) home.assertions)
      "Home assertion failed: ${case.name}\n${
        lib.concatMapStringsSep "\n" (a: a.message) (lib.filter (a: !a.assertion) home.assertions)
      }";
    assert !(case.features.gnome or false) || cfg.services.desktopManager.gnome.enable;
    assert !(case.features.niri or false) || cfg.programs.niri.enable;
    assert cfg.services.displayManager.defaultSession == case.desktop;
    assert cfg.services.displayManager.gdm.enable == (case.loginManager == "gdm");
    assert cfg.services.greetd.enable == (case.loginManager == "greetd");
    assert
      !cfg.services.greetd.enable
      || cfg.security.pam.services.greetd.enableGnomeKeyring == home.features.desktop.keyring.enable;
    assert
      cfg.services.displayManager.dms-greeter.enable
      == (case.loginManager == "greetd" && case.desktop == "niri" && (case.features.dms or false));
    assert cfg.services.pcscd.enable == smartcard;
    assert home.services.gpg-agent.enable == gpg;
    assert !gpg || home.services.gpg-agent.enableSshSupport == ssh;
    assert !gnome || cfg.services.gnome.gcr-ssh-agent.enable == !ssh;
    assert !(smartcard && gpg) || home.programs.gpg.scdaemonSettings.disable-ccid;
    assert cfg.i18n.defaultLocale == "en_US.UTF-8";
    assert home.home.language.base == (if chinese then "zh_CN.UTF-8" else null);
    assert !chinese || home.i18n.inputMethod.type == "fcitx5";
    assert !(home.home.sessionVariables ? GTK_IM_MODULE);
    assert !(home.systemd.user.sessionVariables ? GTK_IM_MODULE);
    assert
      !(chinese && gnome)
      || builtins.elem "kimpanel@kde.org" (
        map (v: v.value) home.dconf.settings."org/gnome/shell".enabled-extensions.value
      );
    assert !(case.features.dms or false) || cfg.programs.dms-shell.systemd.target == "niri.service";
    case.name;
  verifyConflict =
    case:
    let
      cfg = build case;
    in
    assert lib.any (a: lib.hasInfix case.message a.message && !a.assertion) (
      if case.homeAssertion or false then cfg.home-manager.users.test.assertions else cfg.assertions
    );
    case.name;
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  verifyExternal =
    case:
    let
      cfg = build case;
      h = cfg.home-manager.users.test;
    in
    assert lib.assertMsg (lib.all (a: a.assertion) cfg.assertions)
      "External system assertion failed: ${case.name}\n${
        lib.concatMapStringsSep "\n" (a: a.message) (lib.filter (a: !a.assertion) cfg.assertions)
      }";
    assert lib.assertMsg (lib.all (a: a.assertion) h.assertions)
      "External home assertion failed: ${case.name}\n${
        lib.concatMapStringsSep "\n" (a: a.message) (lib.filter (a: !a.assertion) h.assertions)
      }";
    assert lib.assertMsg (case.verify cfg)
      "External capability was changed by a disabled feature: ${case.name}";
    case.name;
in
{
  profiles = import ./profiles.nix { inherit lib; };
  platformContracts = import ../ports/platform-contracts.nix { inherit lib mkHost; };
  combinations = map verify cases;
  rejectedOverrides = map verifyConflict conflictCases;
  externalCapabilities = map verifyExternal externalCases;
  disabledFeatures = import ./disabled.nix { inherit lib build; };
  independentFeatures = import ./independence.nix { inherit lib build; };
  ghostty = import ../home/ghostty.nix { inherit lib mkHost; };
  networking = import ../ports/network.nix { inherit lib build; };
  smartcard = import ../ports/smartcard.nix { inherit lib mkHost; };
  experience = import ../ports/experience.nix {
    inherit
      lib
      mkHost
      build
      rawMkHost
      ;
  };
  printingFirmware = import ../ports/printing-firmware.nix { inherit lib mkHost build; };
  smartcardNative = import ../ports/smartcard-native.nix { inherit lib mkHost build; };
  desktopServices = import ../ports/desktop-services.nix { inherit lib build mkHost; };
  archDesktop = import ../ports/arch-desktop.nix { inherit lib mkHost; };
  commonTools = import ../software/common-tools.nix { inherit lib mkHost; };
  nativeMpv = import ../ports/mpv-native.nix { inherit lib mkHost; };
}
