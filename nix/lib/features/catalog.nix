{
  lib,
  platformRegistry ? import ../platforms,
}:
let
  inherit (platformRegistry)
    all
    linux
    nixos
    desktops
    ;
  settingsOption = description: {
    default = { };
    type = lib.types.lazyAttrsOf lib.types.anything;
    inherit description;
  };

  stacks = import ./desktop-stacks.nix;
  desktopFeatures = lib.unique (lib.concatMap (stack: stack.features) (builtins.attrValues stacks));
  desktopServices = [
    "system.session"
    "system.network"
    "system.audio"
    "system.bluetooth"
    "system.power"
    "system.storage"
  ];
in
import ./availability.nix { inherit lib platformRegistry; } {
  features = {
    autostart = {
      path = [
        "desktop"
        "autostart"
      ];
      platforms = desktops;
      homeModules = [ ../../modules/home/features/autostart.nix ];
      options.entries = import ./autostart.nix { inherit lib; };
    };
    macos = {
      path = [
        "desktop"
        "macos"
      ];
      platforms = [ "darwin" ];
      portScopes = [ "system" ];
      options.settings = settingsOption "Native macOS preferences, following nix-darwin system.defaults";
    };
    usbip = {
      path = [
        "wsl"
        "usbip"
      ];
      platforms = [ "nixos-wsl" ];
      portScopes = [ "system" ];
    };
    mihomo = {
      platforms = all;
      contracts = [ "system.mihomo" ];
      systemModules = [ ../../modules/system/features/mihomo.nix ];
      activation = {
        scope = "system";
        option = [
          "services"
          "mihomo"
          "enable"
        ];
      };
      options = {
        configFile = {
          type = lib.types.strMatching "/.*";
          default = "/etc/mihomo/config.yaml";
          description = "Absolute runtime path to a private Mihomo YAML file; never read during Nix evaluation";
        };
        tunMode = {
          type = lib.types.bool;
          default = true;
          description = "Grant TUN permissions; tun.enable must also be set in the private YAML";
        };
      };
    };
    commonTools = {
      platforms = all;
      homeModules = [ ../../modules/home/features/common-tools.nix ];
    };
    efiTools = {
      platforms = platformRegistry.withCapability "efi";
      software = [ "efibootmgr" ];
      homeModules = [ ../../modules/home/features/efi-tools.nix ];
    };
    chrome = {
      contracts = [ "system.chrome" ];
      platforms = all;
      systemPlatforms = linux;
      systemModules = [ ../../modules/system/features/chrome.nix ];
      options.extensions = {
        default = [ "nngceckbapebfimnlniiiahkandclblb" ]; # Bitwarden
        type = lib.types.listOf (lib.types.strMatching "[a-p]{32}");
        description = "a list of Chrome Web Store extension IDs";
      };
    };
    vscode = {
      platforms = all;
      homeModules = [ ../../modules/home/features/vscode.nix ];
      options.settings = {
        default = {
          "editor.fontFamily" = "'Maple Mono NF CN', monospace";
          "terminal.integrated.fontFamily" = "'Maple Mono NF CN'";
        };
        type = lib.types.lazyAttrsOf lib.types.anything;
        description = "VS Code settings restored at activation; undeclared settings remain user-owned";
      };
    };
    codex = {
      platforms = all;
      software = [ "codex" ];
    };
    coteditor = {
      platforms = [ "darwin" ];
      software = [ "coteditor" ];
    };
    iina = {
      platforms = [ "darwin" ];
      software = [ "iina" ];
    };
    edge = {
      platforms = [ "darwin" ];
      software = [ "edge" ];
    };
    mapleMono = {
      platforms = all;
      software = [
        "maple-mono"
        "maple-mono-plain"
      ];
    };
    screenRotate = {
      options.settings = settingsOption "Screen Rotate extension settings";
      path = [
        "desktop"
        "screenRotate"
      ];
      platforms = [ "nixos" ];
      software = [ "gnome-screen-rotate" ];
      requires = [ "gnome" ];
      activation = {
        scope = "home";
        option = [
          "programs"
          "gnome-shell"
          "enable"
        ];
      };
      homeModules = [ ../../modules/home/features/screen-rotate.nix ];
    };

    plymouth = {
      platforms = [ "nixos" ];
      portScopes = [ "system" ];
    };
    network = {
      default = true;
      platforms = [ "nixos" ];
      portScopes = [ "system" ];
    };
    xdg = {
      default = true;
      platforms = linux;
      homeModules = [ ../../modules/home/features/xdg.nix ];
    };
    git = {
      default = true;
      platforms = all;
      homeModules = [ ../../modules/home/features/git.nix ];
    };
    vim = {
      default = true;
      platforms = all;
      homeModules = [ ../../modules/home/features/vim.nix ];
    };
    shell = {
      default = true;
      platforms = all;
      homeModules = [ ../../modules/home/features/shell.nix ];
      systemPlatforms = nixos ++ [ "darwin" ];
      systemModules = [ ../../modules/system/features/shell.nix ];
    };
    gpg = {
      options.pinentry = {
        type = lib.types.nullOr (
          lib.types.enum [
            "curses"
            "tty"
            "qt"
            "mac"
          ]
        );
        default = null;
        description = "Explicit Nix pinentry variant, or null to use the software provider's default";
      };
      contracts = [ "home.gpg" ];
      default = true;
      platforms = all;
      activation = {
        scope = "home";
        option = [
          "services"
          "gpg-agent"
          "enable"
        ];
      };
      homeModules = [ ../../modules/home/features/gpg.nix ];
    };
    gpgSshSupport = {
      path = [
        "gpg"
        "sshSupport"
      ];
      default = true;
      platforms = all;
      requires = [ "gpg" ];
      homeModules = [ ../../modules/home/features/gpg-ssh.nix ];
      activation = {
        scope = "home";
        option = [
          "services"
          "gpg-agent"
          "enableSshSupport"
        ];
      };
    };
    nixTools = {
      default = true;
      platforms = all;
      homeModules = [ ../../modules/home/features/nix-tools.nix ];
    };
    devel = {
      platforms = all;
      homeModules = [ ../../modules/home/features/devel.nix ];
    };
    smartcard = {
      contracts = [ "system.smartcard" ];
      default = true;
      defaultPlatforms = nixos ++ [ "darwin" ];
      platforms = all;
      options.allowBackgroundAccess = {
        default = false;
        type = lib.types.bool;
        description = "allow this account's PC/SC clients outside an active desktop session (WSL/SSH)";
      };
      systemPlatforms = linux;
      systemModules = [ ../../modules/system/features/smartcard.nix ];
    };
    nixLd = {
      default = true;
      platforms = nixos;
      portScopes = [ "system" ];
    };
    gnome = {
      contracts = desktopServices ++ [ "system.gnome" ];
      portScopes = [
        "home"
        "system"
      ];
      options = {
        settings = settingsOption "GNOME dconf settings keyed by schema path";
        textEditor = import ./gnome-text-editor.nix { inherit lib; };
        flatAppGrid = {
          default = true;
          type = lib.types.bool;
          description = "show GNOME Overview applications without folder groups";
        };
      };
      path = [
        "desktop"
        "gnome"
      ];
      activation = {
        scope = "system";
        option = stacks.gnome.activation;
      };
      platforms = desktops;
      systemPlatforms = desktops;
      homeModules = [ ../../modules/home/features/gnome.nix ];
    };
    niri = {
      contracts = desktopServices ++ [
        "home.niri"
        "system.niri"
      ];
      portScopes = [ "system" ];
      options = {
        settings = settingsOption "structured Niri KDL settings";
        shell = {
          default = null;
          type = lib.types.nullOr (lib.types.enum (builtins.attrNames (import ./desktop-shells.nix)));
          description = "Session shell to enable and select; null selects among enabled shells by priority";
        };
      };
      path = [
        "desktop"
        "niri"
      ];
      activation = {
        scope = "system";
        option = stacks.niri.activation;
      };
      platforms = desktops;
      systemPlatforms = desktops;
      homeModules = [ ../../modules/home/features/niri.nix ];
    };
    dms = {
      contracts = desktopServices ++ [
        "home.dms"
        "home.niri"
        "system.niri"
        "system.dms"
      ];
      portScopes = [
        "system"
      ];
      options = {
        settings = settingsOption "DMS settings.json attributes";
        session = settingsOption "DMS session.json attributes";
      };
      path = [
        "desktop"
        "dms"
      ];
      activation = {
        scope = "system";
        option = [
          "programs"
          "dms-shell"
          "enable"
        ];
      };
      platforms = desktops;
      systemPlatforms = desktops;
      requires = [ "niri" ];
      homeModules = [ ../../modules/home/features/dms.nix ];
    };
    noctalia = {
      contracts = desktopServices ++ [
        "home.noctalia"
        "home.niri"
        "system.noctalia"
        "system.noctalia-greeter"
        "system.niri"
      ];
      portScopes = [ "system" ];
      path = [
        "desktop"
        "noctalia"
      ];
      options.settings = settingsOption "Noctalia TOML settings";
      activation = {
        scope = "system";
        option = [
          "programs"
          "noctalia"
          "enable"
        ];
      };
      platforms = desktops;
      systemPlatforms = desktops;
      requires = [ "niri" ];
      homeModules = [ ../../modules/home/features/noctalia.nix ];
    };
    fileManager = {
      path = [
        "desktop"
        "fileManager"
      ];
      platforms = desktops;
      defaultFrom = desktopFeatures;
      software = [ "nautilus" ];
      homeModules = [ ../../modules/home/features/file-manager.nix ];
      options =
        builtins.mapAttrs
          (_: description: {
            default = true;
            type = lib.types.bool;
            inherit description;
          })
          {
            sortDirectoriesFirst = "sort directories before files";
            showHiddenFiles = "show hidden files by default";
            showCreateLink = "show the Create Link context menu item";
            showDeletePermanently = "show the Delete Permanently context menu item";
          };
    };
    printing = {
      contracts = [
        "system.printing"
        "system.avahi"
      ];
      path = [
        "desktop"
        "printing"
      ];
      platforms = desktops;
      defaultFrom = desktopFeatures;
      systemPlatforms = desktops;
      systemModules = [ ../../modules/system/features/printing.nix ];
    };
    firmware = {
      contracts = [ "system.firmware" ];
      path = [
        "desktop"
        "firmware"
      ];
      platforms = desktops;
      defaultFrom = desktopFeatures;
      homeModules = [ ../../modules/home/features/firmware.nix ];
      systemPlatforms = desktops;
      systemModules = [ ../../modules/system/features/firmware.nix ];
    };
    keyring = {
      path = [
        "desktop"
        "keyring"
      ];
      platforms = linux;
      defaultFrom = desktopFeatures;
    };
    launcher = {
      path = [
        "desktop"
        "launcher"
      ];
      platforms = desktops;
      defaultFrom = desktopFeatures;
      homeModules = [ ../../modules/home/integrations/launcher.nix ];
      options.hiddenEntries = {
        default = [
          "avahi-discover.desktop"
          "bssh.desktop"
          "bvnc.desktop"
          "cups.desktop"
          "qv4l2.desktop"
          "qvidcap.desktop"
          "org.gnome.Terminal.desktop"
          "org.gnome.gedit.desktop"
          "org.gnome.Cheese.desktop"
          "htop.desktop"
          "jconsole-java-openjdk.desktop"
          "jshell-java-openjdk.desktop"
          "nvtop.desktop"
          "cmake-gui.desktop"
          "lstopo.desktop"
          "vim.desktop"
          "gvim.desktop"
          "org.gnome.Tour.desktop"
          "org.gnome.Tecla.desktop"
          "kbd-layout-viewer5.desktop"
          "fcitx5-configtool.desktop"
          "org.fcitx.fcitx5-config-qt.desktop"
          "org.fcitx.fcitx5-migrator.desktop"
          "org.gnome.Epiphany.desktop"
          "org.gnome.Software.desktop"
        ];
        type = lib.types.listOf (lib.types.strMatching "[A-Za-z0-9_.+-]+\\.desktop");
        description = "a list of desktop entry filenames";
      };
    };
    wallpaper = {
      path = [
        "desktop"
        "wallpaper"
      ];
      platforms = desktops;
      defaultFrom = desktopFeatures;
      homeModules = [ ../../modules/home/integrations/desktop-wallpaper.nix ];
      systemPlatforms = [ "nixos" ];
      options = {
        image = {
          default = null;
          type = lib.types.nullOr lib.types.path;
          description = "a path, an absolute filename, or null to leave the desktop wallpaper unmanaged";
        };
        lockImage = {
          default = null;
          type = lib.types.nullOr lib.types.path;
          description = "a path, an absolute filename, or null to leave the lock wallpaper unmanaged";
        };
      };
    };
    ghostty = {
      options.settings = settingsOption "Ghostty configuration settings";
      platforms = all;
      homeModules = [ ../../modules/home/features/ghostty.nix ];
    };
    mpv = {
      options = {
        settings = settingsOption "mpv.conf options";
        scriptOpts = settingsOption "mpv script options, grouped by script name";
      };
      platforms = all;
      homeModules = [ ../../modules/home/features/mpv.nix ];
    };
    chinese = {
      contracts = [ "home.input-method" ];
      portScopes = [ "home" ];
      platforms = desktops;
      options = {
        settings = settingsOption "Fcitx settings: inputMethod, globalOptions and addons";
        englishByDefault = {
          default = true;
          type = lib.types.bool;
          description = "start Rime in English mode";
        };
      };
      homeModules = [ ../../modules/home/features/chinese.nix ];
      systemPlatforms = [ "nixos" ];
    };
  };

  choices = {
    desktopShell = {
      source = {
        feature = "niri";
        option = "shell";
      };
      platforms = desktops;
      providers = builtins.mapAttrs (name: _: [ name ]) (import ./desktop-shells.nix);
      priority = [
        "dms"
        "noctalia"
      ];
      empty = null;
    };
    desktop = {
      platforms = desktops;
      providers = builtins.mapAttrs (_: stack: stack.features) (import ./desktop-stacks.nix);
      sessions = builtins.mapAttrs (_: stack: builtins.removeAttrs stack [ "features" ]) (
        import ./desktop-stacks.nix
      );
      priority = [
        "niri"
        "gnome"
      ];
      empty = null;
    };
  };

  integrations = {
    niri-ghostty = {
      platforms = desktops;
      owners = [
        "niri"
        "ghostty"
      ];
      homeModules = [ ../../modules/home/integrations/niri-ghostty.nix ];
    };
    niri-chinese = {
      platforms = desktops;
      owners = [
        "niri"
        "chinese"
      ];
      homeModules = [ ../../modules/home/integrations/niri-chinese.nix ];
    };
    niri-mpv = {
      platforms = desktops;
      owners = [
        "niri"
        "mpv"
      ];
      homeModules = [ ../../modules/home/integrations/niri-mpv.nix ];
    };
    chrome-browser = {
      platforms = desktops;
      owners = [ "chrome" ];
      homeModules = [ ../../modules/home/integrations/chrome-browser.nix ];
    };
    gpg-smartcard = {
      platforms = nixos;
      owners = [
        "smartcard"
        "gpg"
        "gpgSshSupport"
      ];
      portScopes = [ "home" ];
    };
    gnome-chinese = {
      portScopes = [ "home" ];
      platforms = desktops;
      owners = [ "chinese" ];
    };
    niri-noctalia = {
      platforms = desktops;
      owners = [
        "niri"
        "noctalia"
      ];
      homeModules = [ ../../modules/home/integrations/niri-noctalia.nix ];
    };
    niri-dms = {
      portScopes = [ "home" ];
      platforms = desktops;
      owners = [
        "niri"
        "dms"
      ];
    };
  };
}
