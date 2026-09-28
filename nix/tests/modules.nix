{ inputs }:

let
  inherit (inputs.nixpkgs) lib;
  mkHost = import ../lib/hosts/mk-host.nix {
    inherit lib;
    builders = import ../lib/builders { inherit inputs; };
    settings = {
      features = { };
      user = {
        username = "test";
        git = {
          name = "Test";
          email = "test@example.invalid";
        };
      };
    };
  };
  build =
    case:
    (mkHost "FeatureTest" {
      platform = "nixos";
      features = case.features;
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
  desktopCases = [
    {
      name = "console";
      features = { };
      desktop = null;
      loginManager = "none";
    }
    {
      name = "gnome";
      features = {
        gnome = true;
        chinese = true;
      };
      desktop = "gnome";
      loginManager = "gdm";
    }
    {
      name = "niri";
      features.niri = true;
      desktop = "niri";
      loginManager = "none";
    }
    {
      name = "niri-dms";
      features = {
        niri = true;
        dms = true;
        chinese = true;
      };
      desktop = "niri";
      loginManager = "dms";
    }
    {
      name = "gnome-manual-login";
      features.gnome = true;
      preferences.loginManager = "none";
      desktop = "gnome";
      loginManager = "none";
    }
  ]
  ++
    map
      (desktop: {
        name = "both-${desktop}";
        features = {
          gnome = true;
          niri = true;
        };
        preferences = { inherit desktop; };
        inherit desktop;
        loginManager = "gdm";
      })
      [
        "gnome"
        "niri"
      ]
  ++
    map
      (selection: {
        name = "all-${selection.desktop}-${selection.loginManager}";
        features = {
          gnome = true;
          niri = true;
          dms = true;
          chinese = true;
        };
        preferences = selection;
        inherit (selection) desktop loginManager;
      })
      (
        lib.cartesianProduct {
          desktop = [
            "gnome"
            "niri"
          ];
          loginManager = [
            "gdm"
            "dms"
          ];
        }
      );
  agentCases =
    map
      (state: {
        name = "gnome-gpg-${state.name}";
        features = {
          gnome = true;
          gpg = state.gpg;
        }
        // lib.optionalAttrs (state ? ssh) { gpgSshSupport = state.ssh; };
        desktop = "gnome";
        loginManager = "gdm";
        gpg = state.gpg;
        ssh = state.ssh or false;
      })
      [
        {
          name = "disabled";
          gpg = false;
          ssh = false;
        }
        {
          name = "no-ssh";
          gpg = true;
          ssh = false;
        }
      ];
  cases =
    desktopCases
    ++ agentCases
    ++ [
      {
        name = "smartcard-without-gpg";
        features.gpg = false;
        features.gpgSshSupport = false;
        desktop = null;
        loginManager = "none";
        gpg = false;
        ssh = false;
      }
      {
        name = "gpg-without-smartcard";
        features.smartcard = false;
        desktop = null;
        loginManager = "none";
      }
    ];
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
    assert lib.assertMsg (lib.all (
      a: a.assertion
    ) cfg.assertions) "System assertion failed: ${case.name}";
    assert lib.assertMsg (lib.all (
      a: a.assertion
    ) home.assertions) "Home assertion failed: ${case.name}";
    assert cfg.services.displayManager.defaultSession == case.desktop;
    assert cfg.services.displayManager.gdm.enable == (case.loginManager == "gdm");
    assert cfg.services.displayManager.dms-greeter.enable == (case.loginManager == "dms");
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
  conflictCases = [
    {
      name = "two-login-managers";
      features = {
        gnome = true;
      };
      systemConfig.services.greetd.enable = true;
      message = "cannot both own the login screen";
    }
    {
      name = "two-system-ssh-agents";
      features = { };
      systemConfig.programs.ssh.startAgent = true;
      message = "Multiple SSH agents";
    }
    {
      name = "two-home-ssh-agents";
      features = { };
      homeConfig.services.ssh-agent.enable = true;
      homeAssertion = true;
      message = "cannot own the same user's SSH socket";
    }
    {
      name = "forced-gnome-agent";
      features.gnome = true;
      systemConfig = { lib, ... }: { services.gnome.gcr-ssh-agent.enable = lib.mkForce true; };
      message = "Multiple SSH agents";
    }
    {
      name = "disabled-compositor-dependency";
      features = {
        niri = true;
        dms = true;
      };
      systemConfig.programs.niri.enable = false;
      message = "Feature dms requires niri";
    }
    {
      name = "disabled-gpg-dependency";
      features = { };
      homeConfig.services.gpg-agent = {
        enable = false;
        enableSshSupport = true;
      };
      homeAssertion = true;
      message = "Feature gpgSshSupport requires gpg";
    }
  ];
  verifyConflict =
    case:
    let
      cfg = build case;
    in
    assert lib.any (a: lib.hasInfix case.message a.message && !a.assertion) (
      if case.homeAssertion or false then cfg.home-manager.users.test.assertions else cfg.assertions
    );
    case.name;
  allOff = lib.genAttrs (builtins.attrNames (import ../lib/features/catalog.nix).features) (_: false);
  externalCases = [
    {
      name = "dms-mergeable-configuration";
      features = allOff // {
        dms = true;
      };
      homeConfig.programs.dank-material-shell = {
        settings = {
          lockScreenWallpaperPath = "/test/lock.png";
          fontFamily = "Test Sans";
        };
        session = {
          wallpaperPath = "/test/desktop.png";
          isLightMode = true;
        };
      };
      verify =
        cfg:
        let
          dms = cfg.home-manager.users.test.programs.dank-material-shell;
        in
        dms.settings.fontFamily == "Test Sans"
        && dms.settings.lockScreenWallpaperPath == "/test/lock.png"
        && dms.session.wallpaperPath == "/test/desktop.png"
        && dms.session.isLightMode
        && !dms.systemd.enable
        && cfg.programs.dms-shell.systemd.enable;
    }
    {
      name = "dms-runtime-owned-configuration";
      features = allOff // {
        dms = true;
      };
      homeConfig = { lib, ... }: {
        programs.dank-material-shell = {
          settings = lib.mkForce { };
          session = lib.mkForce { };
        };
      };
      verify =
        cfg:
        let
          home = cfg.home-manager.users.test;
        in
        !(home.xdg.configFile ? "DankMaterialShell/settings.json")
        && !(home.xdg.stateFile ? "DankMaterialShell/session.json");
    }
    {
      name = "external-plymouth";
      features = allOff;
      systemConfig = { lib, ... }: {
        boot.plymouth = {
          enable = lib.mkDefault true;
          theme = "spinner";
        };
      };
      verify =
        cfg:
        cfg.boot.plymouth.enable
        && cfg.boot.plymouth.theme == "spinner"
        && builtins.elem "splash" cfg.boot.kernelParams;
    }
    {
      name = "chinese-with-external-gnome";
      features = allOff // {
        chinese = true;
      };
      systemConfig.services.desktopManager.gnome.enable = true;
      verify =
        cfg:
        lib.any (p: lib.hasInfix "kimpanel" (lib.getName p)) cfg.home-manager.users.test.home.packages
        && cfg.environment.gnome.excludePackages == [ ];
    }
    {
      name = "gpg-with-external-pcsc";
      features = allOff // {
        gpg = true;
      };
      systemConfig.services.pcscd.enable = true;
      verify = cfg: cfg.home-manager.users.test.programs.gpg.scdaemonSettings.disable-ccid;
    }
    {
      name = "niri-with-external-dms";
      features = allOff // {
        niri = true;
      };
      systemConfig.programs.dms-shell.enable = true;
      verify =
        cfg:
        lib.hasAttrByPath [
          "binds"
          "Mod+Space"
        ] cfg.home-manager.users.test.wayland.windowManager.niri.settings
        && !cfg.services.displayManager.dms-greeter.enable;
    }
    {
      name = "devel-without-other-features";
      features = allOff // {
        devel = true;
      };
      verify =
        cfg:
        let
          h = cfg.home-manager.users.test;
          names = map lib.getName h.home.packages;
        in
        lib.all (name: builtins.elem name names) [
          "git"
          "ripgrep"
          "fd"
          "jq"
          "tree"
          "curl"
          "wget"
          "clang-wrapper"
          "clang-tools"
          "llvm"
          "lldb"
          "cmake"
          "python3"
        ]
        && !h.programs.git.enable
        && !h.programs.zsh.enable;
    }
    {
      name = "external-development-tools";
      features = allOff;
      homeConfig = { pkgs, ... }: {
        home.packages = [
          pkgs.llvmPackages.clang
          pkgs.python3
        ];
      };
      verify =
        cfg:
        let
          names = map lib.getName cfg.home-manager.users.test.home.packages;
        in
        builtins.elem "clang-wrapper" names
        && builtins.elem "python3" names
        && !(builtins.elem "cmake" names)
        && !(builtins.elem "lldb" names);
    }
    {
      name = "external-home-and-system-capabilities";
      features = allOff;
      systemConfig = { lib, ... }: {
        programs.zsh.enable = lib.mkDefault true;
        programs.nix-ld.enable = lib.mkDefault true;
        services.pcscd.enable = lib.mkDefault true;
      };
      homeConfig = { lib, pkgs, ... }: {
        programs.git.enable = lib.mkDefault true;
        programs.zsh.enable = lib.mkDefault true;
        programs.gpg.enable = lib.mkDefault true;
        services.gpg-agent = {
          enable = lib.mkDefault true;
          enableSshSupport = lib.mkDefault true;
          pinentry.package = lib.mkDefault pkgs.pinentry-tty;
        };
        programs.mpv.enable = lib.mkDefault true;
        programs.ghostty.enable = lib.mkDefault true;
        home.packages = [
          pkgs.nh
          pkgs.nixfmt
        ];
        home.language.base = lib.mkDefault "zh_CN.UTF-8";
        i18n.inputMethod = {
          enable = lib.mkDefault true;
          type = lib.mkDefault "fcitx5";
        };
        xdg = {
          enable = lib.mkDefault true;
          localBinInPath = lib.mkDefault false;
          userDirs.enable = lib.mkDefault false;
        };
      };
      verify =
        cfg:
        let
          h = cfg.home-manager.users.test;
        in
        cfg.programs.zsh.enable
        && cfg.programs.nix-ld.enable
        && cfg.services.pcscd.enable
        && h.programs.git.enable
        && h.programs.zsh.enable
        && h.programs.gpg.enable
        && h.services.gpg-agent.enableSshSupport
        && lib.getName h.services.gpg-agent.pinentry.package == "pinentry-tty"
        && h.programs.mpv.enable
        && h.programs.ghostty.enable
        && !(h.programs.mpv.config ? hwdec)
        && !(h.programs.ghostty.settings ? theme)
        && !h.programs.zsh.oh-my-zsh.enable
        && h.xdg.enable
        && !h.xdg.localBinInPath
        && !h.xdg.userDirs.enable
        && h.home.language.base == "zh_CN.UTF-8"
        && h.i18n.inputMethod.enable
        && h.i18n.inputMethod.fcitx5.addons == [ ]
        && builtins.elem "nh" (map lib.getName h.home.packages)
        && builtins.elem "nixfmt" (map lib.getName h.home.packages);
    }
    {
      name = "external-gnome-gdm-gcr";
      features = allOff;
      systemConfig = { lib, ... }: {
        services.desktopManager.gnome.enable = lib.mkDefault true;
        services.displayManager.gdm.enable = lib.mkDefault true;
        services.displayManager.defaultSession = lib.mkDefault "gnome";
        services.gnome.gcr-ssh-agent.enable = lib.mkDefault true;
      };
      verify =
        cfg:
        cfg.services.desktopManager.gnome.enable
        && cfg.services.displayManager.gdm.enable
        && cfg.services.gnome.gcr-ssh-agent.enable
        && cfg.environment.gnome.excludePackages == [ ];
    }
    {
      name = "external-dms-without-our-niri-requirement";
      features = allOff;
      systemConfig = { lib, ... }: {
        programs.dms-shell = {
          enable = lib.mkDefault true;
          systemd.target = lib.mkDefault "graphical-session.target";
        };
      };
      verify =
        cfg:
        cfg.programs.dms-shell.enable
        && !cfg.programs.niri.enable
        && cfg.programs.dms-shell.systemd.target == "graphical-session.target";
    }
    {
      name = "external-niri-and-dms-greeter";
      features = allOff;
      systemConfig = { lib, ... }: {
        programs.niri.enable = lib.mkDefault true;
        programs.dms-shell.enable = lib.mkDefault true;
        services.displayManager.dms-greeter = {
          enable = lib.mkDefault true;
          compositor.name = "niri";
        };
      };
      verify =
        cfg:
        cfg.programs.niri.enable
        && cfg.services.displayManager.dms-greeter.enable
        && !cfg.home-manager.users.test.wayland.windowManager.niri.enable;
    }
    {
      name = "dms-with-external-niri";
      features = allOff // {
        dms = true;
      };
      systemConfig = { lib, ... }: { programs.niri.enable = lib.mkDefault true; };
      verify =
        cfg:
        cfg.programs.niri.enable
        && cfg.programs.dms-shell.enable
        && cfg.programs.dms-shell.systemd.target == "niri.service"
        && !cfg.home-manager.users.test.wayland.windowManager.niri.enable;
    }
    {
      name = "gpg-ssh-with-external-agent";
      features = allOff // {
        gpgSshSupport = true;
      };
      homeConfig = { lib, pkgs, ... }: {
        programs.gpg.enable = lib.mkDefault true;
        services.gpg-agent.enable = lib.mkDefault true;
        services.gpg-agent.pinentry.package = pkgs.pinentry-tty;
      };
      verify =
        cfg:
        cfg.home-manager.users.test.services.gpg-agent.enableSshSupport
        && lib.getName cfg.home-manager.users.test.services.gpg-agent.pinentry.package == "pinentry-tty";
    }
  ];
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
  combinations = map verify cases;
  rejectedOverrides = map verifyConflict conflictCases;
  externalCapabilities = map verifyExternal externalCases;
  disabledFeatures = import ./feature-off.nix { inherit lib build; };
  independentFeatures = import ./feature-independence.nix { inherit lib build; };
  networking = import ./network.nix { inherit lib build; };
}
