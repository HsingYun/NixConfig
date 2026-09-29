{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  resolve = import ../lib/software/resolve.nix { inherit lib; };
  fixture = {
    editor = {
      nix = {
        package = "nix-editor";
        capabilities = [ "store-package" ];
      };
      homebrew = {
        type = "brew";
        name = "editor";
      };
      pacman = {
        type = "package";
        name = "editor";
      };
      dependencies = [ "font" ];
    };
    font = {
      pacman = {
        type = "aur";
        name = "editor-font";
      };
      nix = {
        package = "nix-font";
        capabilities = [ "store-package" ];
      };
      homebrew = {
        type = "cask";
        name = "font-editor";
      };
    };
    tool.nix = {
      package = "nix-tool";
      capabilities = [ "store-package" ];
    };
    alias = {
      homebrew = {
        type = "brew";
        name = "editor";
      };
    };
    unavailable = {
      homebrew = {
        name = "unavailable";
        type = "brew";
        available = false;
      };
      nix = {
        package = "nix-fallback";
        capabilities = [ "store-package" ];
      };
    };
  };
  plan =
    args:
    resolve (
      {
        catalog = fixture;
        requirements.editor = { };
        packageManager = "homebrew";
        platform = "darwin";
      }
      // args
    );
  succeeds = value: (builtins.tryEval (builtins.deepSeq value true)).success;
  native = plan {
    requirements = {
      editor = { };
      alias = { };
    };
  };
  nix = plan {
    packageManager = "nix";
    platform = "nixos";
  };
  fallback = plan {
    requirements = {
      editor.capabilities = [ "store-package" ];
      tool = { };
      unavailable = { };
    };
  };
  scopes = plan {
    packageManager = "nix";
    requirements.editor.scopes = [
      "system"
      "home"
    ];
  };
  removed = plan { requirements = { }; };
  remaining = plan { requirements.font = { }; };
  featureCatalog = (import ../lib/features/catalog.nix).features;
  applicationFeatures = lib.filterAttrs (_: entry: entry ? software) featureCatalog;
  catalog = import ../lib/software/catalog.nix {
    pkgs = inputs.nixpkgs.legacyPackages.aarch64-darwin;
  };
  # Every package-only feature must reference registered software, even if off.
  knownApplications = lib.all (entry: lib.all (name: catalog ? ${name}) entry.software) (
    builtins.attrValues applicationFeatures
  );
  rawMkHost = import ../lib/hosts/mk-host.nix {
    inherit lib;
    builders = import ../lib/builders { inherit inputs; };
    settings = {
      features = { };
      user = {
        username = "test";
        git.name = "Test";
        git.email = "test@example.invalid";
      };
    };
  };
  allOff = lib.genAttrs (builtins.attrNames featureCatalog) (_: false);
  mkHost = import ./host-fixture.nix {
    inherit lib;
    mkHost = rawMkHost;
  };
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
    externalPkg.packages = [ "mpv" ];
  } { mpv = true; } { };
  pinentryOverride = ownershipHost {
    type = "nix";
    externalPkg.packages = [ "pinentry-qt" ];
  } { gpg = true; } ({ pkgs, ... }: { software.packageOverrides.pinentry = pkgs.pinentry-tty; });
  pinentryBypass = ownershipHost "nix" { gpg = true; } (
    { pkgs, ... }: { services.gpg-agent.pinentry.package = pkgs.pinentry-tty; }
  );
  nativeOverride = ownershipHost {
    type = "pacman";
    externalPkg.packages = [ "git" ];
  } { git = true; } ({ pkgs, ... }: { software.packageOverrides.git = pkgs.gitMinimal; });
  darwinOwnership =
    (mkHost "DarwinOwnership" {
      platform = "darwin";
      packageManager = {
        type = "homebrew";
        externalPkg.brews = [
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
      externalPkg.packages = [ "gcc" ];
    };
  };
  off = darwin allOff;
  arch =
    (mkHost "ArchSoftwareTest" {
      platform = "arch";
      packageManager = {
        type = "pacman";
        externalPkg = {
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
  nativeExternal = plan {
    packageManager = {
      type = "homebrew";
      externalPkg = {
        brews = [
          "editor"
          "extra"
        ];
        casks = [ "font-editor" ];
      };
    };
  };
  pacman = plan {
    platform = "arch";
    packageManager = {
      type = "pacman";
      externalPkg = {
        packages = [ "editor" ];
        aur = [
          "editor-font"
          "extra-aur"
        ];
      };
    };
  };
  pacmanFallback = plan {
    platform = "arch";
    packageManager = "pacman";
    requirements = {
      editor.capabilities = [ "store-package" ];
      tool = { };
    };
  };
  nixExternal = resolve {
    inherit catalog;
    pkgs = inputs.nixpkgs.legacyPackages.aarch64-darwin;
    platform = "darwin";
    requirements.vim = { };
    packageManager = {
      type = "nix";
      externalPkg.packages = [
        "vim"
        "vim"
      ];
    };
  };

in
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
assert
  removed.binPaths == [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];
assert builtins.elem "/opt/homebrew/bin" remaining.binPaths;
assert
  (plan {
    nativePrefix = "/usr/local";
    requirements = { };
  }).binPaths == [
    "/usr/local/bin"
    "/usr/local/sbin"
  ];
assert nix.managerBinPaths == [ ];
assert pacman.managerBinPaths == [ ];
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
    "ripgrep"
    "tree"
    "wget"
    "aria2"
  ];
assert
  builtins.head darwinOwnedHome.home.sessionPath == "${darwinOwnedHome.programs.gpg.package}/bin";
assert !(builtins.elem "/opt/homebrew/opt/gnupg/bin" darwinOwnedHome.home.sessionPath);
assert lib.hasPrefix "${darwinOwnedHome.programs.gpg.package}/bin:"
  darwinOwnership.environment.systemPath;
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
assert efiArchNix.software.resolved.efibootmgr.scopes == [ "home" ];
assert builtins.elem "efibootmgr" (map lib.getName efiArchNix.home.packages);
assert
  nativeExternal.installations.homebrew.brews == [
    "editor"
    "extra"
  ];
assert nativeExternal.installations.homebrew.casks == [ "font-editor" ];
assert
  pacman.installations.pacman.packages == [
    "editor"
    "base-devel"
    "git"
  ];
assert
  pacman.installations.pacman.aur == [
    "editor-font"
    "extra-aur"
  ];
assert pacman.resolved.font.nativeType == "aur";
assert pacmanFallback.resolved.editor.provider == "nix";
assert pacmanFallback.resolved.tool.provider == "nix";
assert builtins.length nixExternal.installations.nix.homePackages == 1;
assert lib.all (a: a.assertion) arch.assertions;
assert archPlan.resolved.vim.provider == "pacman";
assert archPlan.resolved.clang.nativeName == "clang";
assert archPlan.resolved.ghostty.provider == "pacman";
assert archPlan.resolved.maple-mono.nativeType == "aur";
assert lib.count (name: name == "git") archPlan.installations.pacman.packages == 1;
assert lib.count (name: name == "clang") archPlan.installations.pacman.packages == 1;
assert lib.count (name: name == "google-chrome") archPlan.installations.pacman.aur == 1;
assert builtins.elem "base-devel" archPlan.installations.pacman.packages;
assert arch.home.activation.installNativePackages.after == [ "writeBoundary" ];
assert arch.home.activation.installNativePackages.before == [ "linkGeneration" ];
assert lib.hasInfix "--aur" arch.home.activation.installNativePackages.data;
assert !(off.home-manager.users.test.home.activation ? installNativePackages);
assert lib.all (args: !(succeeds (plan args))) [
  { packageManager = "apt"; }
  {
    packageManager = {
      type = "homebrew";
      externalPkg.aur = [ "x" ];
    };
  }
  {
    packageManager = {
      type = "homebrew";
      externalPkg.brews = [ "--bad" ];
    };
  }
  {
    packageManager = {
      type = "homebrew";
      externalPkg.brews = [ "x; touch BAD" ];
    };
  }
  {
    packageManager = {
      type = "homebrew";
      externalPkg.brews = "wrong";
    };
  }
  {
    packageManager = {
      type = "homebrew";
      extra = [ ];
    };
  }
  {
    platform = "arch";
    packageManager = {
      type = "pacman";
      externalPkg.aur = [ "editor" ];
    };
  }
  {
    platform = "arch";
    packageManager = {
      type = "pacman";
      externalPkg.aur = [ "git" ];
    };
  }
];
assert native.installations.homebrew.brews == [ "editor" ];
assert native.installations.homebrew.casks == [ "font-editor" ];
assert native.installations.nix.homePackages == [ ];
assert nix.installations.homebrew.brews == [ ] && nix.installations.homebrew.casks == [ ];
assert builtins.length nix.installations.nix.homePackages == 2;
assert fallback.resolved.editor.provider == "nix";
assert fallback.resolved.tool.provider == "nix";
assert fallback.resolved.unavailable.provider == "nix";
assert fallback.resolved.font.provider == "homebrew";
assert
  builtins.length scopes.installations.nix.systemPackages == 2
  && builtins.length scopes.installations.nix.homePackages == 2;
assert
  removed.resolved == { }
  && removed.installations.homebrew.brews == [ ]
  && removed.installations.homebrew.casks == [ ];
assert remaining.installations.homebrew.casks == [ "font-editor" ];
assert
  !(succeeds (plan {
    packageManager = "pacman";
  }));
assert
  !(succeeds (plan {
    packageManager = "typo";
  }));
assert
  !(succeeds (plan {
    platform = "nixos";
  }));
assert
  !(succeeds (plan {
    requirements.typo = { };
  }));
assert
  !(succeeds (plan {
    requirements.editor.capabilities = [ "missing-capability" ];
  }));
assert
  !(succeeds (plan {
    catalog = fixture // {
      font = fixture.font // {
        dependencies = [ "editor" ];
      };
    };
  }));
assert
  !(succeeds (plan {
    catalog = fixture // {
      editor = fixture.editor // {
        homebew = { };
      };
    };
  }));
assert
  !(succeeds (plan {
    catalog = fixture // {
      editor = fixture.editor // {
        homebrew = {
          name = "editor";
          type = "typo";
        };
      };
    };
  }));
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
assert home.software.resolved.mpv.provider == "nix";
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
    "dependencies"
    "shared-packages"
    "scopes"
    "removal"
    "unknown-manager"
    "unimplemented-backend"
    "wrong-platform"
    "unknown-software"
    "missing-capability"
    "dependency-cycle"
  ];
  applicationFeatures = builtins.attrNames applicationFeatures;
  consistency = import ./software-consistency.nix {
    inherit
      inputs
      mkHost
      allOff
      ownershipHost
      ;
  };
  homebrew = { inherit brews casks; };
}
