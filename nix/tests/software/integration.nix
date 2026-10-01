{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  succeeds = value: (builtins.tryEval (builtins.deepSeq value true)).success;
  inherit (import ./host-cases.nix { inherit inputs; })
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
in
assert import ./resolver.nix { inherit inputs; };
assert lib.all (name: nixDevel.software.resolved.${name}.provider == "nix") develSoftware;
assert lib.all (name: home.software.resolved.${name}.provider == "homebrew") develSoftware;
assert lib.all (name: archPlan.resolved.${name}.provider == "pacman") develSoftware;
assert lib.all (name: !(off.home-manager.users.test.software.resolved ? ${name})) develSoftware;
assert
  nixDevel.software.resolved.gcc.package.meta.priority
  > nixDevel.software.resolved.clang.package.meta.priority;
assert lib.count (name: name == "rust") brews == 1;
assert lib.count (name: name == "rust") archPlan.installations.pacman.packages == 1;
assert
  home.software.resolved.coreutils.command "ls" == "/opt/homebrew/opt/coreutils/libexec/gnubin/ls";
assert
  home.software.resolved.python.command "python3" == "/opt/homebrew/opt/python@3.14/bin/python3";
assert builtins.elem "/opt/homebrew/opt/coreutils/libexec/gnubin" home.home.sessionPath;
assert builtins.elem "/opt/homebrew/opt/python@3.14/libexec/bin" home.home.sessionPath;
assert
  lib.drop ((builtins.length home.home.sessionPath) - 2) home.home.sessionPath == [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];
assert lib.hasInfix ":/opt/homebrew/bin:/opt/homebrew/sbin:" withApps.environment.systemPath;
assert lib.all (name: builtins.elem name brews) [
  "abseil"
  "node"
  "openjdk"
  "telnet"
];
assert lib.all (name: builtins.elem name archPlan.installations.pacman.packages) [
  "abseil-cpp"
  "nodejs"
  "jdk-openjdk"
  "inetutils"
];
assert lib.all (a: a.assertion) (
  mpvExtra.assertions ++ pinentryOverride.assertions ++ nativeOverride.assertions
);
assert lib.count (p: lib.hasPrefix "mpv" (lib.getName p)) mpvExtra.home.packages == 1;
assert mpvExtra.software.resolved.mpv.runtimePackage == mpvExtra.programs.mpv.finalPackage;
assert
  mpvExtra.software.resolved.mpv.command "mpv" == "${mpvExtra.programs.mpv.finalPackage}/bin/mpv";
assert !(builtins.elem "${mpvExtra.software.resolved.mpv.package}/bin" mpvExtra.home.sessionPath);
assert
  mpvExtra.software.plan.installations.nix.modulePackages == [ mpvExtra.programs.mpv.finalPackage ];
assert
  pinentryOverride.services.gpg-agent.pinentry.package
  == pinentryOverride.software.resolved.pinentry.package;
assert builtins.elem "pinentry-tty" (map lib.getName pinentryOverride.home.packages);
assert !(builtins.elem "pinentry-qt" (map lib.getName pinentryOverride.home.packages));
assert !(succeeds pinentryBypass.home.username);
assert nativeOverride.software.resolved.git.provider == "nix";
assert !(builtins.elem "git" nativeOverride.software.plan.installations.pacman.packages);
assert lib.all (a: a.assertion) (darwinOwnership.assertions ++ darwinOwnedHome.assertions);
assert
  map (p: p.name) darwinOwnership.homebrew.brews == [
    "curl"
    "fastfetch"
    "fd"
    "htop"
    "jq"
    "nano"
    "pinentry-mac"
    "ripgrep"
    "tree"
    "wget"
    "aria2"
  ];
assert
  builtins.head darwinOwnedHome.home.sessionPath == "${darwinOwnedHome.home.profileDirectory}/bin";
assert !(builtins.elem "/opt/homebrew/opt/gnupg/bin" darwinOwnedHome.home.sessionPath);
assert
  !(lib.hasInfix (builtins.unsafeDiscardStringContext "${darwinOwnedHome.programs.gpg.package}/bin") darwinOwnership.environment.systemPath);
assert lib.hasInfix "/run/current-system/sw/bin" darwinOwnership.environment.systemPath;
assert
  (lib.findFirst (
    p: lib.hasPrefix "gcc" (lib.getName p)
  ) null extraPriority.installations.nix.homePackages).meta.priority
  > extraPriority.resolved.clang.package.meta.priority;
assert !(archPlan.resolved ? efibootmgr);
assert !(fontOnly.software.resolved ? efibootmgr);
assert !(efiNixosOff.home-manager.users.test.software.resolved ? efibootmgr);
assert efiNixos.home-manager.users.test.software.resolved.efibootmgr.provider == "nix";
assert efiNixos.home-manager.users.test.software.resolved.efibootmgr.scopes == [ "system" ];
assert builtins.elem "efibootmgr" (map lib.getName efiNixos.environment.systemPackages);
assert !(builtins.elem "efibootmgr" (map lib.getName efiNixosOff.environment.systemPackages));
assert efiArch.software.resolved.efibootmgr.provider == "pacman";
assert builtins.elem "efibootmgr" efiArch.software.plan.installations.pacman.packages;
assert efiArchNix.software.resolved.efibootmgr.scopes == [ "system" ];
assert builtins.elem "efibootmgr" (
  map lib.getName efiArchNix.hostSystem.environment.systemPackages
);
assert lib.all (a: a.assertion) arch.assertions;
assert archPlan.resolved.vim.provider == "pacman";
assert archPlan.resolved.clang.nativeName == "clang";
assert archPlan.resolved.ghostty.provider == "pacman";
assert archPlan.resolved.maple-mono.nativeType == "aur";
assert lib.count (name: name == "git") archPlan.installations.pacman.packages == 1;
assert lib.count (name: name == "clang") archPlan.installations.pacman.packages == 1;
assert lib.count (name: name == "google-chrome") archPlan.installations.pacman.aur == 1;
assert builtins.elem "base-devel" archPlan.installations.pacman.packages;
assert lib.all (name: builtins.elem name arch.home.activation.installNativePackages.after) [
  "writeBoundary"
  "nativeSystemBegin"
];
assert lib.all (name: builtins.elem name arch.home.activation.installNativePackages.before) [
  "linkGeneration"
  "systemProfile"
];
assert lib.hasInfix "--aur" arch.home.activation.installNativePackages.data;
assert !(off.home-manager.users.test.home.activation ? installNativePackages);
assert lib.all (a: a.assertion) (rotationAssertions true);
assert lib.any (a: !a.assertion && lib.hasInfix "screenRotate" a.message) (
  rotationAssertions false
);
assert fontOnly.fonts.fontconfig.enable;
assert !(fontOnly.software.resolved ? ghostty);
assert fontOnly.software.resolved.maple-mono.provider == "nix";
assert builtins.elem "MapleMono-NF-CN" (map lib.getName fontOnly.home.packages);
assert knownApplications;
assert lib.all (a: a.assertion) (withApps.assertions ++ home.assertions);
assert home.programs.git.package == null;
assert home.software.resolved.vim.provider == "homebrew";
assert home.software.resolved.ghostty.provider == "homebrew";
assert home.software.resolved.clang.provider == "homebrew";
assert home.software.resolved.zsh.provider == "nix";
assert home.software.resolved.gnupg.provider == "nix";
assert home.software.resolved.mpv.provider == "homebrew";
assert home.programs.mpv.package == null;
assert home.xdg.configFile ? "mpv/scripts/modernx.lua";
assert home.software.resolved.pinentry.provider == "homebrew";
assert home.services.gpg-agent.pinentry.package == null;
assert lib.hasInfix
  "pinentry-program ${home.software.nativePrefix}/opt/pinentry-mac/bin/pinentry-mac"
  home.home.file."${home.programs.gpg.homedir}/gpg-agent.conf".text;
assert lib.count (name: name == "pinentry-mac") brews == 1;
assert !(builtins.elem "pinentry-mac" (map lib.getName home.home.packages));
assert home.software.plan.resolved.ghostty.package == null;
assert !(builtins.elem "ghostty" (map lib.getName home.home.packages));
assert lib.count (name: name == "llvm") brews == 1;
assert lib.count (name: name == "font-maple-mono-nf-cn") casks == 1;
assert !(builtins.elem "gnupg" brews);
assert builtins.elem "font-maple-mono-nf-cn" (
  map (entry: entry.name) withoutGhostty.homebrew.casks
);
assert !(builtins.elem "ghostty" (map (entry: entry.name) withoutGhostty.homebrew.casks));
assert !(builtins.elem "vim" (map (entry: entry.name) off.homebrew.brews));
assert !(builtins.elem "font-maple-mono-nf-cn" (map (entry: entry.name) off.homebrew.casks));
{
  resolver = [
    "devel-provider-mappings-and-removal"
    "external-identity-ownership"
    "runtime-package-priority"
    "package-overrides-and-binding-validation"
    "efi-tools-opt-in-and-scopes"
    "external-packages"
    "pacman-and-aur"
    "native-preference"
    "nix-preference"
    "capability-fallback"
    "missing-provider-fallback"
    "unavailable-provider-fallback"
    "merged-resource-requests"
    "shared-packages"
    "scopes"
    "removal"
    "unknown-manager"
    "unimplemented-backend"
    "wrong-platform"
    "unknown-software"
    "missing-capability"
  ];
  applicationFeatures = builtins.attrNames applicationFeatures;
  manifests = import ./manifests.nix { inherit inputs; };
  placement = import ./placement.nix { inherit inputs ownershipHost; };
  consumers = import ./consumers.nix { inherit inputs ownershipHost; };
  consistency = import ./ownership.nix {
    inherit
      inputs
      mkHost
      allOff
      ownershipHost
      ;
  };
  homebrew = { inherit brews casks; };
}
