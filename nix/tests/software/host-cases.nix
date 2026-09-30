{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  resolve = import ../../lib/software/resolve.nix { inherit lib; };
  featureCatalog = (import ../../lib/features/catalog.nix { inherit lib; }).features;
  applicationFeatures = lib.filterAttrs (_: entry: entry ? software) featureCatalog;
  catalog = import ../../lib/software/catalog.nix {
    pkgs = inputs.nixpkgs.legacyPackages.aarch64-darwin;
  };
  # Every package-only feature must reference registered software, even if off.
  knownApplications = lib.all (entry: lib.all (name: catalog ? ${name}) entry.software) (
    builtins.attrValues applicationFeatures
  );
  allOff = lib.genAttrs (builtins.attrNames featureCatalog) (_: false);
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  darwin =
    features:
    (mkHost "SoftwareTest" {
      platform = "darwin";
      inherit features;
      systemConfig.system.stateVersion = 6;
      homeConfig.home.stateVersion = "26.05";
    }).configuration.config;
  withApps = darwin (
    allOff
    // {
      ghostty = true;
      mapleMono = true;
      vim = true;
      git = true;
      shell = true;
      devel = true;
      gpg = true;
      mpv = true;
    }
  );
  home = withApps.home-manager.users.test;
  brews = map (entry: entry.name) withApps.homebrew.brews;
  casks = map (entry: entry.name) withApps.homebrew.casks;
  withoutGhostty = darwin (allOff // { mapleMono = true; });
  rotation =
    gnome:
    (mkHost "RotationSoftwareTest" {
      platform = "nixos";
      features = allOff // {
        inherit gnome;
        screenRotate = true;
      };
      hardwareConfig = {
        boot.initrd.enable = false;
        boot.kernel.enable = false;
        boot.loader.grub.enable = false;
      };
      systemConfig.system.stateVersion = "26.11";
      homeConfig.home.stateVersion = "26.05";
    }).configuration.config;
  rotationAssertions =
    gnome:
    let
      c = rotation gnome;
    in
    c.assertions ++ c.home-manager.users.test.assertions;
  fontOnly =
    (mkHost "FontsTest" {
      platform = "arch";
      packageManager = "nix";
      features = allOff // {
        mapleMono = true;
      };
      homeConfig.home.stateVersion = "26.05";
    }).configuration.config;
  efiHost =
    platform: packageManager: enabled:
    (mkHost "EfiToolsTest" (
      {
        inherit platform packageManager;
        features = allOff // {
          efiTools = enabled;
        };
        homeConfig.home.stateVersion = "26.05";
      }
      // lib.optionalAttrs (platform == "nixos") {
        hardwareConfig = {
          boot.initrd.enable = false;
          boot.kernel.enable = false;
          boot.loader.grub.enable = false;
        };
        systemConfig.system.stateVersion = "26.11";
      }
    )).configuration.config;
  efiNixos = efiHost "nixos" "nix" true;
  efiNixosOff = efiHost "nixos" "nix" false;
  efiArch = efiHost "arch" "pacman" true;
  efiArchNix = efiHost "arch" "nix" true;
  ownershipHost =
    packageManager: enabledFeatures: homeConfig:
    (mkHost "OwnershipTest" {
      platform = "arch";
      inherit packageManager;
      features = allOff // enabledFeatures;
      homeConfig = {
        imports = [ homeConfig ];
        home.stateVersion = "26.05";
      };
    }).configuration.config;
  mpvExtra = ownershipHost {
    type = "nix";
    extraPkg.nix.packages = [ "mpv" ];
  } { mpv = true; } { };
  pinentryOverride = ownershipHost {
    type = "nix";
    extraPkg.nix.packages = [ "pinentry-qt" ];
  } { gpg = true; } ({ pkgs, ... }: { software.packageOverrides.pinentry = pkgs.pinentry-tty; });
  pinentryBypass = ownershipHost "nix" { gpg = true; } (
    { pkgs, ... }: { services.gpg-agent.pinentry.package = pkgs.pinentry-tty; }
  );
  nativeOverride = ownershipHost {
    type = "pacman";
    extraPkg.pacman.packages = [ "git" ];
  } { git = true; } ({ pkgs, ... }: { software.packageOverrides.git = pkgs.gitMinimal; });
  darwinOwnership =
    (mkHost "DarwinOwnership" {
      platform = "darwin";
      packageManager = {
        type = "homebrew";
        extraPkg.homebrew.brews = [
          "gnupg"
          "pinentry-mac"
          "aria2"
        ];
      };
      features = allOff // {
        gpg = true;
      };
      systemConfig.system.stateVersion = 6;
      homeConfig.home.stateVersion = "26.05";
    }).configuration.config;
  darwinOwnedHome = darwinOwnership.home-manager.users.test;
  develSoftware = [
    "coreutils"
    "abseil-cpp"
    "gcc"
    "gdb"
    "git-lfs"
    "go"
    "nodejs"
    "openjdk"
    "protobuf"
    "rust"
    "cargo"
    "typescript"
    "python"
    "telnet"
  ];
  nixDevel = ownershipHost "nix" { devel = true; } { };
  extraPriority = resolve {
    inherit catalog;
    pkgs = inputs.nixpkgs.legacyPackages.aarch64-darwin;
    platform = "darwin";
    requirements.clang = { };
    packageManager = {
      type = "nix";
      extraPkg.nix.packages = [ "gcc" ];
    };
  };
  off = darwin allOff;
  arch =
    (mkHost "ArchSoftwareTest" {
      platform = "arch";
      packageManager = {
        type = "pacman";
        extraPkg.pacman = {
          packages = [
            "git"
            "git"
          ];
          aur = [ "google-chrome" ];
        };
      };
      features = allOff // {
        ghostty = true;
        devel = true;
        vim = true;
        chrome = true;
      };
      homeConfig.home.stateVersion = "26.05";
    }).configuration.config;
  archPlan = arch.software.plan;
in
{
  inherit
    featureCatalog
    applicationFeatures
    catalog
    knownApplications
    allOff
    mkHost
    darwin
    withApps
    home
    brews
    casks
    withoutGhostty
    rotation
    rotationAssertions
    fontOnly
    efiHost
    efiNixos
    efiNixosOff
    efiArch
    efiArchNix
    ownershipHost
    mpvExtra
    pinentryOverride
    pinentryBypass
    nativeOverride
    darwinOwnership
    darwinOwnedHome
    develSoftware
    nixDevel
    extraPriority
    off
    arch
    archPlan
    ;
}
