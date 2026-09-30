# Shared inputs and behavior requirements. Platform-specific evidence belongs in
# observations/, so adding a port does not change these scenarios.
{ lib }:
let
  service = options: {
    configure = { enabled, ... }: {
      system = lib.mkMerge (map (option: lib.setAttrByPath (lib.splitString "." option) enabled) options);
    };
  };
  homeFile = name: { home, ... }: home.xdg.configFile ? ${name};
  hasInputFiles =
    home:
    lib.any (name: name == "fcitx5" || lib.hasPrefix "fcitx5/" name) (
      builtins.attrNames home.xdg.configFile
    );
in
{
  "system.printing" = service [ "services.printing.enable" ];
  "system.avahi" = service [ "services.avahi.enable" ];
  "system.firmware" = service [ "services.fwupd.enable" ];
  "system.network" = service [ "networking.networkmanager.enable" ];
  "system.bluetooth" = service [ "hardware.bluetooth.enable" ];
  "system.power" = service [ "services.upower.enable" ];
  "system.storage" = service [
    "services.udisks2.enable"
    "services.gvfs.enable"
  ];
  "system.smartcard" = service [
    "services.pcscd.enable"
    "security.polkit.enable"
  ];
  "system.audio" = service [
    "services.pipewire.enable"
    "services.pipewire.alsa.enable"
    "services.pipewire.pulse.enable"
    "security.rtkit.enable"
  ];
  "system.chrome" = {
    configure = { enabled, ... }: {
      system.programs.chromium = {
        enable = enabled;
        extraOpts.ContractProbe = true;
      };
    };
  };
  "system.gnome" = {
    configure = { enabled, ... }: {
      system.services = {
        desktopManager.gnome.enable = enabled;
        displayManager = {
          gdm.enable = enabled;
          defaultSession = if enabled then "gnome" else null;
        };
      };
    };
  };
  "system.niri" = {
    configure = { enabled, ... }: {
      system = {
        programs.niri.enable = enabled;
        services.greetd.enable = enabled;
        services.displayManager.defaultSession = if enabled then "niri" else null;
      };
    };
  };
  "system.dms" = {
    configure = { enabled, ... }: {
      system.programs = {
        niri.enable = enabled;
        dms-shell.enable = enabled;
      };
    };
  };
  "system.session" = {
    configure = { enabled, port, ... }: {
      system =
        if builtins.elem "system.gnome" port.contracts then
          {
            services.desktopManager.gnome.enable = enabled;
            services.displayManager.gdm.enable = enabled;
            services.displayManager.defaultSession = if enabled then "gnome" else null;
          }
        else
          {
            programs.niri.enable = enabled;
            services.greetd.enable = enabled;
            services.displayManager.defaultSession = if enabled then "niri" else null;
          };
    };
  };
  "home.niri" = {
    configure = { enabled, ... }: {
      system.programs.niri.enable = enabled;
      home.wayland.windowManager.niri = {
        enable = enabled;
        systemd.enable = false;
        settings.input.keyboard.xkb.layout = "us";
      };
    };
    observe = homeFile "niri/config.kdl";
  };
  "home.noctalia" = {
    configure = { enabled, ... }: {
      home.programs.noctalia = {
        enable = enabled;
        systemd.enable = false;
        settings.theme.mode = "dark";
      };
    };
    observe = homeFile "noctalia/config.toml";
    scenarios.validationDisabled = {
      configure.home.programs.noctalia = {
        enable = true;
        systemd.enable = false;
        checkConfig = false;
        settings.theme.mode = "dark";
      };
      verify =
        { home, ... }:
        home.xdg.configFile ? "noctalia/config.toml" && !(home.home.activation ? validateArchNoctalia);
    };
  };
  "system.noctalia-greeter" = {
    configure = { enabled, ... }: {
      system.services.displayManager.noctalia-greeter = {
        enable = enabled;
        settings.session.default = "niri";
      };
    };
  };
  "system.noctalia" = {
    configure = { enabled, ... }: {
      system.programs.noctalia = {
        enable = enabled;
        systemd.enable = enabled;
      };
    };
  };
  "home.dms" = {
    configure = { enabled, ... }: {
      home.programs.dank-material-shell = {
        enable = enabled;
        systemd.enable = false;
        settings.contractProbe = true;
      };
    };
    observe = homeFile "DankMaterialShell/settings.json";
  };
  "home.input-method" = {
    configure = { enabled, ... }: {
      home.i18n.inputMethod = {
        enable = enabled;
        type = "fcitx5";
      };
      home.i18n.inputMethod.fcitx5.settings.globalOptions.Hotkey.TriggerKeys = "Control+space";
    };
    observe = { home, ... }: home.xdg.configFile ? "fcitx5/config" || home.xdg.configFile ? fcitx5;
    scenarios = {
      emptySettings = {
        configure.home.i18n.inputMethod = {
          enable = true;
          type = "fcitx5";
        };
        verify =
          { home, ... }:
          !hasInputFiles home && home.systemd.user.services ? fcitx5-daemon;
      };
      explicitEmptyAddon = {
        configure.home.i18n.inputMethod = {
          enable = true;
          type = "fcitx5";
          fcitx5.settings.addons.classicui = { };
        };
        # The upstream INI type expands a declared addon into empty sections.
        # Naming it still requests a file; omitting the addon leaves it unmanaged.
        verify = { home, ... }: hasInputFiles home;
      };
      desktopAutostart = {
        configure.home.i18n.inputMethod = {
          enable = true;
          type = "fcitx5";
          fcitx5.systemd.enable = false;
        };
        verify =
          { home, ... }:
          !hasInputFiles home && !(home.systemd.user.services ? fcitx5-daemon);
      };
    };
  };
  "home.gpg" = {
    configure = { enabled, ... }: {
      home.programs.gpg.enable = enabled;
      home.services.gpg-agent.enable = enabled;
    };
    observe = { home, ... }: home.home.file ? "${home.programs.gpg.homedir}/gpg-agent.conf";
  };
}
