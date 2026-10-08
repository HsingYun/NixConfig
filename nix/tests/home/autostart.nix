{
  inputs,
  pkgs,
  hosts,
}:
let
  inherit (pkgs) lib;
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  ports = (import ../../lib/platforms).definitions;
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  arguments = [
    ""
    "two words"
    "中文"
    "'\"\\"
    "$HOME"
    "$(touch injected)"
    "%f %U %%"
    "line\nbreak"
  ];
  environment = {
    AUTOSTART_LITERAL = "'\"\\ $HOME $(touch injected)\n%f";
    UID = "literal";
  };
  probe = {
    command = [
      "${pkgs.python3}/bin/python3"
      "-c"
      "import json, os, sys; print(json.dumps(dict(argv=sys.argv[1:], cwd=os.getcwd(), env={k: os.environ[k] for k in ['AUTOSTART_LITERAL', 'UID']})))"
    ]
    ++ arguments;
    inherit environment;
    workingDirectory = "/";
  };
  make =
    platform: desktop: enabled: extra:
    let
      bootstrap = import ../fixtures/platform.nix { port = ports.${platform}; };
    in
    (mkHost "Autostart" {
      inherit platform;
      inherit (bootstrap) hardwareConfig systemConfig;
      features = allOff // {
        autostart = enabled;
        ${desktop} = true;
      };
      homeConfig = {
        imports = [ extra ];
        home.stateVersion = "26.05";
        desktop.autostart.entries = {
          probe = lib.mapAttrs (_: lib.mkDefault) probe;
          disabled.enable = false;
        };
      };
    }).views.home;
  cases = lib.cartesianProduct {
    platform = [
      "nixos"
      "arch"
    ];
    desktop = [
      "gnome"
      "niri"
    ];
  };
  verify =
    { platform, desktop }:
    let
      enabled = make platform desktop true { };
      disabled = make platform desktop false { };
      overridden = make platform desktop true {
        desktop.autostart.entries.probe.workingDirectory = "/tmp";
      };
      removed = make platform desktop true { desktop.autostart.entries.probe.enable = false; };
      upstreamDisabled = make platform desktop true { xdg.autostart.enable = false; };
    in
    assert lib.all (h: lib.all (a: a.assertion) h.assertions) [
      enabled
      disabled
      overridden
      removed
      upstreamDisabled
    ];
    assert enabled.xdg.autostart.enable && !disabled.xdg.autostart.enable;
    assert builtins.length enabled.xdg.autostart.entries == 1;
    assert disabled.xdg.autostart.entries == [ ] && !(disabled.xdg.configFile ? autostart);
    assert removed.xdg.autostart.entries == [ ] && !(removed.xdg.configFile ? autostart);
    assert !(upstreamDisabled.xdg.configFile ? autostart);
    assert overridden.desktop.autostart.entries.probe.command == probe.command;
    assert overridden.desktop.autostart.entries.probe.workingDirectory == "/tmp";
    {
      inherit platform desktop;
      entry = builtins.head enabled.xdg.autostart.entries;
      override = builtins.head overridden.xdg.autostart.entries;
      directory = enabled.xdg.configFile.autostart.source;
    };
  # Validate the public types without evaluating a complete host per bad input.
  valid =
    entries:
    (builtins.tryEval (
      builtins.deepSeq
        (lib.evalModules {
          modules = [
            ../../modules/home/shared/autostart.nix
            { desktop.autostart.entries = entries; }
          ];
        }).config.desktop.autostart.entries
        true
    )).success;
  missingDirectory = make "arch" "gnome" true {
    desktop.autostart.entries.probe.workingDirectory = "/nixconfig-nonexistent-autostart-test";
  };
  hostEntries =
    map
      (
        name:
        let
          home = hosts.${name}.views.home;
        in
        assert home.features.desktop.autostart.enable;
        assert
          home.desktop.autostart.entries.terminal.command == home.desktop.applications.terminal.command;
        assert !(home.wayland.windowManager.niri.settings ? spawn-at-startup);
        builtins.head home.xdg.autostart.entries
      )
      [
        "NixOS-PC"
        "ArchLinux"
      ];
  report = pkgs.writeText "autostart-cases.json" (
    builtins.toJSON {
      cases = map verify cases;
      inherit arguments environment hostEntries;
      missingDirectory = builtins.head missingDirectory.xdg.autostart.entries;
    }
  );
in
assert valid { test = probe; };
assert !(valid { "../escape" = probe; });
assert
  !(valid {
    test = probe // {
      command = [ ];
    };
  });
assert
  !(valid {
    test = probe // {
      command = [ "" ];
    };
  });
assert
  !(valid {
    test = probe // {
      environment."BAD-NAME" = "value";
    };
  });
assert
  !(valid {
    test = probe // {
      workingDirectory = "relative";
    };
  });
assert !hosts.NixOS-Pad.views.home.features.desktop.autostart.enable;
assert hosts.NixOS-Pad.views.home.desktop.autostart.entries == { };
pkgs.runCommand "desktop-autostart"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.desktop-file-utils
    ];
  }
  ''
    python ${./autostart.py} ${report}
    touch "$out"
  ''
