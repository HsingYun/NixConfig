{ lib }:
let
  inherit (import ../hosts/platforms.nix)
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

in
{
  features = {
    commonTools = {
      platforms = all;
      homeModules = [ ../../modules/home/features/common-tools.nix ];
    };
    efiTools = {
      platforms = [
        "arch"
        "nixos"
      ];
      software = [ "efibootmgr" ];
      homeModules = [ ../../modules/home/features/efi-tools.nix ];
    };
    chrome = {
      contracts = [ "system.chrome" ];
      platforms = all;
      software = [ "chrome" ];
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
      software = [ "vscode" ];
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
      systemModules = [ ../../ports/nixos/system/plymouth.nix ];
    };
    network = {
      default = true;
      platforms = [ "nixos" ];
      systemModules = [ ../../ports/nixos/system/network.nix ];
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
      homeModules = [ ../../modules/home/features/smartcard.nix ];
      systemPlatforms = linux;
      systemModules = [ ../../modules/system/features/smartcard.nix ];
    };
    nixLd = {
      default = true;
      platforms = nixos;
      systemModules = [ ../../ports/nixos/system/nix-ld.nix ];
    };
    gnome = {
      contracts = [ "system.desktop" ];
      portScopes = [
        "home"
        "system"
      ];
      options = {
        settings = settingsOption "GNOME dconf settings keyed by schema path";
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
        option = [
          "services"
          "desktopManager"
          "gnome"
          "enable"
        ];
      };
      platforms = desktops;
      systemPlatforms = desktops;
      homeModules = [ ../../modules/home/features/gnome.nix ];
    };
    niri = {
      contracts = [
        "home.niri"
        "system.desktop"
      ];
      portScopes = [
        "home"
        "system"
      ];
      options.settings = settingsOption "structured Niri KDL settings";
      path = [
        "desktop"
        "niri"
      ];
      activation = {
        scope = "system";
        option = [
          "programs"
          "niri"
          "enable"
        ];
      };
      platforms = desktops;
      systemPlatforms = desktops;
      homeModules = [ ../../modules/home/features/niri.nix ];
    };
    dms = {
      contracts = [
        "home.dms"
        "system.desktop"
      ];
      portScopes = [
        "home"
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
    fileManager = {
      path = [
        "desktop"
        "fileManager"
      ];
      platforms = desktops;
      defaultFrom = [
        "gnome"
        "niri"
        "dms"
      ];
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
      contracts = [ "system.printing" ];
      path = [
        "desktop"
        "printing"
      ];
      platforms = desktops;
      defaultFrom = [
        "gnome"
        "niri"
        "dms"
      ];
      systemPlatforms = desktops;
      systemModules = [ ../../modules/system/features/printing.nix ];
    };
    firmware = {
      contracts = [ "system.printing" ];
      path = [
        "desktop"
        "firmware"
      ];
      platforms = desktops;
      defaultFrom = [
        "gnome"
        "niri"
        "dms"
      ];
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
      defaultFrom = [
        "gnome"
        "niri"
        "dms"
      ];
    };
    launcher = {
      path = [
        "desktop"
        "launcher"
      ];
      platforms = desktops;
      defaultFrom = [
        "gnome"
        "niri"
        "dms"
      ];
      homeModules = [ ../../modules/integrations/launcher.nix ];
      options.hiddenEntries = {
        default = [
          "avahi-discover.desktop"
          "bssh.desktop"
          "bvnc.desktop"
          "cups.desktop"
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
      defaultFrom = [
        "gnome"
        "niri"
        "dms"
      ];
      homeModules = [ ../../modules/integrations/desktop-wallpaper.nix ];
      systemPlatforms = [ "nixos" ];
      systemModules = [ ../../modules/integrations/desktop-wallpaper-system.nix ];
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
      platforms = all;
      homeModules = [ ../../modules/home/features/ghostty.nix ];
    };
    mpv = {
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
      systemModules = [ ../../ports/nixos/system/chinese.nix ];
    };
  };

  choices = {
    desktop = {
      platforms = [
        "arch"
        "nixos"
      ];
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
    chrome-browser = {
      platforms = all;
      owners = [ "chrome" ];
      homeModules = [ ../../modules/integrations/chrome-browser.nix ];
    };
    gpg-smartcard = {
      platforms = nixos;
      owners = [
        "smartcard"
        "gpg"
        "gpgSshSupport"
      ];
      homeModules = [ ../../modules/integrations/smartcard.nix ];
    };
    gnome-chinese = {
      portScopes = [ "home" ];
      platforms = desktops;
      owners = [ "chinese" ];
    };
    niri-dms = {
      portScopes = [ "home" ];
      platforms = desktops;
      owners = [ "niri" ];
    };
  };
}
