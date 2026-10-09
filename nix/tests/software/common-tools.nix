{ lib, mkHost }:
let
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  names = [
    "aria2"
    "gnupg"
    "gnutls"
    "graphviz"
    "ncurses"
    "openssl"
    "pinentry"
    "rsync"
    "sqlite"
    "xz"
    "zlib"
    "zstd"
  ];
  make =
    platform: manager: features: homeConfig:
    (mkHost "CommonTools" {
      inherit platform;
      packageManager = manager;
      features = allOff // features;
      systemConfig = if platform == "darwin" then { system.stateVersion = 6; } else null;
      homeConfig = {
        imports = [ homeConfig ];
        home.stateVersion = "26.05";
      };
    }).views.home;
  arch = make "arch" "pacman" { commonTools = true; } { };
  darwin = make "darwin" "homebrew" { commonTools = true; } { };
  nix = make "arch" "nix" { commonTools = true; } { };
  gpg = make "arch" "pacman" {
    commonTools = true;
    gpg = true;
  } { };
  disabled = make "arch" "pacman" { } { };
  override = make "arch" "pacman" { commonTools = true; } (
    { pkgs, ... }: { software.packageOverrides.aria2 = pkgs.aria2; }
  );
  pinentryCase =
    variant: homeConfig:
    let
      platform = if variant == "mac" || variant == null then "darwin" else "arch";
    in
    (mkHost "PinentryVariant" {
      inherit platform;
      packageManager = if platform == "darwin" then "homebrew" else "pacman";
      features = allOff // {
        gpg = true;
      };
      featureConfig.gpg.pinentry = variant;
      systemConfig = if platform == "darwin" then { system.stateVersion = 6; } else null;
      homeConfig = {
        imports = [ homeConfig ];
        home.stateVersion = "26.05";
      };
    }).views.home;
  pinentryVariants = lib.genAttrs [ "curses" "tty" "qt" "mac" ] (variant: pinentryCase variant { });
  pinentryDefault = pinentryCase null { };
  pinentryOverride = pinentryCase "mac" (
    { pkgs, ... }: { software.packageOverrides.pinentry = pkgs.pinentry-tty; }
  );
in
assert lib.all (cfg: lib.all (a: a.assertion) cfg.assertions) [
  arch
  darwin
  nix
  gpg
  disabled
  override
  pinentryDefault
  pinentryOverride
  pinentryVariants.curses
  pinentryVariants.tty
  pinentryVariants.qt
  pinentryVariants.mac
];
assert lib.all (
  variant:
  let
    cfg = pinentryVariants.${variant};
  in
  cfg.software.resolved.pinentry.provider == "nix"
  && lib.getName cfg.software.resolved.pinentry.package == "pinentry-${variant}"
  && cfg.services.gpg-agent.pinentry.package == cfg.software.resolved.pinentry.package
  && !(builtins.elem "pinentry-mac" cfg.software.plan.installations.homebrew.brews)
  && !(builtins.elem "pinentry" cfg.software.plan.installations.pacman.packages)
) (builtins.attrNames pinentryVariants);
assert pinentryDefault.software.resolved.pinentry.provider == "homebrew";
assert pinentryDefault.software.resolved.pinentry.nativeName == "pinentry-mac";
assert pinentryDefault.services.gpg-agent.pinentry.package == null;
assert pinentryOverride.software.resolved.pinentry.provider == "nix";
assert lib.getName pinentryOverride.services.gpg-agent.pinentry.package == "pinentry-tty";
assert lib.all (name: arch.software.resolved.${name}.provider == "pacman") names;
assert lib.all (name: darwin.software.resolved.${name}.provider == "homebrew") names;
assert lib.all (name: nix.software.resolved.${name}.provider == "nix") names;
assert darwin.software.resolved.openssl.nativeName == "openssl@4";
assert darwin.software.resolved.pinentry.nativeName == "pinentry-mac";
assert !arch.programs.gpg.enable && !arch.services.gpg-agent.enable;
assert gpg.software.resolved.gnupg.provider == "nix";
assert gpg.software.resolved.pinentry.provider == "pacman";
assert gpg.services.gpg-agent.pinentry.package == null;
assert lib.hasInfix "pinentry-program /usr/bin/pinentry"
  gpg.home.file."${gpg.programs.gpg.homedir}/gpg-agent.conf".text;
assert !(builtins.elem "gnupg" gpg.software.plan.installations.pacman.packages);
assert builtins.elem "pinentry" gpg.software.plan.installations.pacman.packages;
assert lib.all (name: !(disabled.software.requirements ? ${name})) names;
assert override.software.resolved.aria2.provider == "nix";
assert override.software.resolved.rsync.provider == "pacman";
{
  inherit names;
  preferredProviders = [
    "pacman"
    "homebrew"
    "nix"
  ];
  capabilityFallback = true;
  disabledFeature = true;
  packageOverrides = true;
  explicitPinentryVariants = builtins.attrNames pinentryVariants;
}
