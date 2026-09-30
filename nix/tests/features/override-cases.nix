{ lib, allOff }:
let
  externalCases = [
    {
      name = "disabled-home-keyring-removes-system-integration";
      features = allOff // {
        niri = true;
        keyring = true;
      };
      homeConfig.services.gnome-keyring.enable = false;
      verify =
        cfg:
        !cfg.services.gnome.gnome-keyring.enable && !cfg.security.pam.services.greetd.enableGnomeKeyring;
    }
    {
      name = "external-home-keyring-enables-system-integration";
      features = allOff;
      homeConfig.services.gnome-keyring.enable = true;
      verify = cfg: cfg.services.gnome.gnome-keyring.enable;
    }
    {
      name = "upstream-default-session-override";
      features = allOff // {
        gnome = true;
        niri = true;
      };
      preferences.desktop = "gnome";
      systemConfig.services.displayManager.defaultSession = "niri";
      verify =
        cfg: cfg.services.displayManager.defaultSession == "niri" && cfg.services.displayManager.gdm.enable;
    }
    {
      name = "no-dconf-consumer";
      features = allOff;
      verify = cfg: !cfg.programs.dconf.enable;
    }
    {
      name = "external-dconf-settings";
      features = allOff;
      homeConfig.dconf.settings."org/example/test".enabled = true;
      verify = cfg: cfg.programs.dconf.enable;
    }
    {
      name = "external-dconf-database";
      features = allOff;
      homeConfig.dconf.databases.secondary."org/example/test".enabled = true;
      verify = cfg: cfg.programs.dconf.enable;
    }
    {
      name = "disabled-dconf-consumer";
      features = allOff;
      homeConfig.dconf = {
        enable = false;
        settings."org/example/test".enabled = true;
      };
      verify = cfg: !cfg.programs.dconf.enable;
    }
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
          names = map lib.getName (h.home.packages ++ cfg.environment.systemPackages);
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
          "coreutils"
          "abseil-cpp"
          "gcc-wrapper"
          "gdb"
          "git-lfs"
          "go"
          "nodejs"
          "openjdk"
          "protobuf"
          "rustc"
          "cargo"
          "typescript"
          "inetutils"
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
        software.packageOverrides.pinentry = pkgs.pinentry-tty;
      };
      verify =
        cfg:
        cfg.home-manager.users.test.services.gpg-agent.enableSshSupport
        && lib.getName cfg.home-manager.users.test.services.gpg-agent.pinentry.package == "pinentry-tty";
    }
  ];
in
externalCases
