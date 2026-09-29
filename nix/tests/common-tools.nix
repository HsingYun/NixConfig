{ lib, mkHost }:
let
  allOff = lib.genAttrs (builtins.attrNames (import ../lib/features/catalog.nix).features) (_: false);
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
    let
      cfg =
        (mkHost "CommonTools" {
          inherit platform;
          packageManager = manager;
          features = allOff // features;
          systemConfig = if platform == "darwin" then { system.stateVersion = 6; } else null;
          homeConfig = {
            imports = [ homeConfig ];
            home.stateVersion = "26.05";
          };
        }).configuration.config;
    in
    if platform == "darwin" then cfg.home-manager.users.test else cfg;
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
in
assert lib.all (cfg: lib.all (a: a.assertion) cfg.assertions) [
  arch
  darwin
  nix
  gpg
  disabled
  override
];
assert lib.all (name: arch.software.resolved.${name}.provider == "pacman") names;
assert lib.all (name: darwin.software.resolved.${name}.provider == "homebrew") names;
assert lib.all (name: nix.software.resolved.${name}.provider == "nix") names;
assert darwin.software.resolved.openssl.nativeName == "openssl@4";
assert darwin.software.resolved.pinentry.nativeName == "pinentry-mac";
assert !arch.programs.gpg.enable && !arch.services.gpg-agent.enable;
assert gpg.software.resolved.gnupg.provider == "nix";
assert gpg.software.resolved.pinentry.provider == "nix";
assert !(builtins.elem "gnupg" gpg.software.plan.installations.pacman.packages);
assert !(builtins.elem "pinentry" gpg.software.plan.installations.pacman.packages);
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
}
