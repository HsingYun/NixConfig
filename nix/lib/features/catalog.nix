let
  inherit (import ../hosts/platforms.nix)
    all
    linux
    nixos
    desktops
    ;
  settingsOption = description: {
    default = { };
    check = builtins.isAttrs;
    inherit description;
  };
  imagePath =
    value:
    value == null
    || builtins.isPath value
    || (builtins.isString value && builtins.match "/.*" value != null);
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
      platforms = all;
      software = [ "chrome" ];
      options.extensions = {
        default = [ "nngceckbapebfimnlniiiahkandclblb" ]; # Bitwarden
        check =
          value:
          builtins.isList value
          && builtins.all (id: builtins.isString id && builtins.match "[a-p]{32}" id != null) value;
        description = "a list of Chrome Web Store extension IDs";
      };
    };
    vscode = {
      platforms = all;
      software = [ "vscode" ];
      homeModules = [ ../../modules/home/features/vscode.nix ];
      options.initialSettings = {
        default = {
          "editor.fontFamily" = "'Maple Mono NF CN', monospace";
          "terminal.integrated.fontFamily" = "'Maple Mono NF CN'";
        };
        check = builtins.isAttrs;
        description = "VS Code settings seeded once; existing values and later edits remain user-owned";
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
      systemModules = [ ../../modules/system/features/plymouth.nix ];
    };
    network = {
      default = true;
      platforms = [ "nixos" ];
      systemModules = [ ../../modules/system/features/network.nix ];
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
      systemModules = [ ../../modules/system/features/shell.nix ];
    };
    gpg = {
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
      default = true;
      defaultPlatforms = nixos ++ [ "darwin" ];
      platforms = all;
      options.allowBackgroundAccess = {
        default = false;
        check = builtins.isBool;
        description = "allow this account's PC/SC clients outside an active desktop session (WSL/SSH)";
      };
      homeModules = [ ../../modules/home/features/smartcard.nix ];
      systemPlatforms = nixos;
      systemModules = [ ../../modules/system/features/smartcard.nix ];
    };
    nixLd = {
      default = true;
      platforms = nixos;
      systemModules = [ ../../modules/system/features/nix-ld.nix ];
    };
    gnome = {
      options.settings = settingsOption "GNOME dconf settings keyed by schema path";
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
      systemPlatforms = [ "nixos" ];
      homeModules = [ ../../modules/home/features/gnome.nix ];
      systemModules = [ ../../modules/system/features/gnome.nix ];
    };
    niri = {
      options.settings = settingsOption "structured Niri KDL settings";
      activationByPlatform.arch = {
        scope = "home";
        option = [
          "wayland"
          "windowManager"
          "niri"
          "enable"
        ];
      };
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
      systemPlatforms = [ "nixos" ];
      homeModules = [ ../../modules/home/features/niri.nix ];
      systemModules = [ ../../modules/system/features/niri.nix ];
    };
    dms = {
      options = {
        settings = settingsOption "DMS settings.json attributes";
        session = settingsOption "DMS session.json attributes";
      };
      activationByPlatform.arch = {
        scope = "home";
        option = [
          "programs"
          "dank-material-shell"
          "enable"
        ];
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
      systemPlatforms = [ "nixos" ];
      requires = [ "niri" ];
      homeModules = [ ../../modules/home/features/dms.nix ];
      homeModulesByPlatform = {
        nixos = [ ../../modules/home/software/dms-nix.nix ];
        arch = [ ../../modules/home/platforms/arch/dms.nix ];
      };
      systemModules = [ ../../modules/system/features/dms.nix ];
    };
    printing = {
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
      systemPlatforms = [ "nixos" ];
      systemModules = [ ../../modules/system/features/printing.nix ];
    };
    firmware = {
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
      systemPlatforms = [ "nixos" ];
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
          "org.gnome.Epiphany.desktop"
          "org.gnome.Software.desktop"
        ];
        check =
          value:
          builtins.isList value
          && builtins.all (
            name: builtins.isString name && builtins.match "[A-Za-z0-9_.+-]+\\.desktop" name != null
          ) value;
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
          check = imagePath;
          description = "a path, an absolute filename, or null to leave the desktop wallpaper unmanaged";
        };
        lockImage = {
          default = null;
          check = imagePath;
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
      platforms = desktops;
      options = {
        settings = settingsOption "Fcitx settings: inputMethod, globalOptions and addons";
        englishByDefault = {
          default = true;
          check = builtins.isBool;
          description = "start Rime in English mode";
        };
      };
      homeModules = [ ../../modules/home/features/chinese.nix ];
      homeModulesByPlatform = {
        arch = [ ../../modules/home/platforms/arch/chinese.nix ];
        nixos = [ ../../modules/home/software/chinese-nix.nix ];
      };
      systemPlatforms = [ "nixos" ];
      systemModules = [ ../../modules/system/features/chinese.nix ];
    };
  };

  choices = {
    desktop = {
      platforms = [
        "arch"
        "nixos"
      ];
      providers = {
        gnome = "gnome";
        niri = "niri";
      };
      empty = null;
    };
    loginManager = {
      platforms = [
        "arch"
        "nixos"
      ];
      providers = {
        gdm = "gnome";
        greetd = [
          "niri"
          "dms"
        ];
      };
      empty = "none";
      alternatives = [ "none" ];
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
      platforms = desktops;
      owners = [ "chinese" ];
      homeModules = [ ../../modules/integrations/gnome-chinese.nix ];
    };
    niri-dms = {
      platforms = desktops;
      owners = [ "niri" ];
      homeModules = [ ../../modules/integrations/niri-dms.nix ];
    };
  };
}
