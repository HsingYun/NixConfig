{ lib, pkgs }:
let
  # Type probes are not complete activation configurations.
  # Portable input examples, not platform defaults. Native adapters may use
  # package=null internally even when an upstream module requires a derivation.
  withBooleans = value: [
    value
    (lib.mapAttrsRecursiveCond (v: !lib.isDerivation v) (
      _: v: if builtins.isBool v then !v else v
    ) value)
  ];
  examples = [
    (withBooleans {
      programs.gpg = {
        enable = true;
        package = pkgs.hello;
      };
      services.gpg-agent = {
        enable = true;
        enableSshSupport = true;
        pinentry.package = pkgs.hello;
      };
    })
    (withBooleans {
      programs.dank-material-shell = {
        enable = true;
        package = pkgs.hello;
        settings = {
          theme = "example";
          enabled = true;
          values = [
            1
            "two"
          ];
        };
        session.wallpaperPath = "/example.png";
        clipboardSettings.enabled = true;
        enableCalendarEvents = true;
        systemd.enable = true;
      };
    })
    (withBooleans {
      services.displayManager.noctalia-greeter = {
        enable = true;
        settings.session.default = "niri";
        extraArgs = [
          "--"
          "--session"
          "niri"
        ];
      };
    })
    (withBooleans {
      programs.noctalia = {
        enable = true;
        package = pkgs.hello;
        systemd.enable = true;
        checkConfig = true;
        settings.theme.mode = "dark";
        customPalettes.example = {
          primary = "#ffffff";
        };
      };
    })
    (withBooleans {
      programs.noctalia = {
        enable = true;
        systemd = {
          enable = true;
          target = "niri.service";
        };
      };
    })
    (withBooleans {
      wayland.windowManager.niri = {
        enable = true;
        package = pkgs.hello;
        settings.input.keyboard.xkb.layout = "us";
        systemd.enable = true;
      };
    })
    (withBooleans {
      i18n.inputMethod = {
        enable = true;
        type = "fcitx5";
        fcitx5 = {
          addons = [ pkgs.hello ];
          waylandFrontend = true;
          systemd.enable = true;
          sessionVariables.XMODIFIERS = "@im=fcitx";
          settings = {
            inputMethod."Groups/0".Name = "Default";
            globalOptions.Behavior.ActiveByDefault = true;
            addons.classicui = {
              globalSection.Theme = "example";
              sections.General.Vertical = true;
            };
          };
        };
      };
    })
    (withBooleans {
      services = {
        printing.enable = true;
        avahi = {
          enable = true;
          nssmdns4 = true;
        };
        fwupd.enable = true;
      };
    })
    (withBooleans {
      services.pcscd.enable = true;
      security.polkit = {
        enable = true;
        extraConfig = "// example policy\n";
      };
    })
    (withBooleans {
      programs.chromium = {
        enable = true;
        extraOpts = {
          ExampleEnabled = true;
          ExampleList = [ "example" ];
        };
      };
    })
    (withBooleans {
      programs = {
        niri.enable = true;
        dms-shell = {
          enable = true;
          systemd.enable = true;
        };
      };
      services = {
        desktopManager.gnome.enable = true;
        displayManager = {
          defaultSession = "niri";
          gdm.enable = true;
          dms-greeter.enable = true;
        };
        greetd = {
          enable = true;
          settings.default_session = {
            command = "example-greeter";
            user = "greeter";
          };
        };
        pipewire = {
          enable = true;
          alsa.enable = true;
          pulse.enable = true;
        };
        upower.enable = true;
        udisks2.enable = true;
        gvfs.enable = true;
      };
      networking.networkmanager.enable = true;
      hardware.bluetooth.enable = true;
      security.rtkit.enable = true;
    })
  ];
  contracts = import ./.;
  allExamples = lib.concatLists examples;
in
lib.mapAttrs (
  _: contract:
  let
    options =
      (lib.evalModules {
        specialArgs = { inherit pkgs; };
        modules = [ contract.module ];
      }).options;
    paths = map (option: option.loc) (
      lib.collect lib.isOption (builtins.removeAttrs options [ "_module" ])
    );
  in
  map (
    example:
    lib.foldl' lib.recursiveUpdate { } (
      map (path: lib.setAttrByPath path (lib.getAttrFromPath path example)) (
        lib.filter (path: lib.hasAttrByPath path example) paths
      )
    )
  ) allExamples
) contracts
