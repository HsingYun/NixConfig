{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost rawMkHost;
  ports = (import ../../lib/platforms).definitions;
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  home =
    platform: dms: overrides: extraHome:
    let
      bootstrap = import ../fixtures/platform.nix { port = ports.${platform}; };
    in
    (mkHost "NiriDms" {
      inherit platform;
      inherit (bootstrap) hardwareConfig systemConfig;
      features = allOff // {
        niri = true;
        ghostty = true;
        chrome = true;
        mpv = true;
        inherit dms;
      };
      featureConfig = lib.recursiveUpdate {
        desktop.niri.settings._children = [
          {
            output = {
              _args = [ "DP-5" ];
              scale = 2;
            };
          }
        ];
      } overrides;
      homeConfig = {
        imports = [ extraHome ];
        home.stateVersion = "26.05";
      };
    }).views.home;
  check =
    platform:
    let
      enabled = home platform true { } { };
      disabled = home platform false { } { };
      inactive = home platform true { chrome.enable = false; } {
        programs.ghostty.enable = false;
        programs.google-chrome.enable = false;
        programs.mpv.enable = false;
      };
      custom = home platform true {
        desktop = {
          niri.settings.binds."Mod+M".spawn = [ "custom-task-manager" ];
          niri.settings.input.keyboard.xkb.layout = "de";
          niri.settings.input.mouse = {
            left-handed = { };
            accel-speed = 0.6;
          };
          niri.settings.input.touchpad = {
            tap = { };
            natural-scroll = { };
          };
          niri.settings.layout.gaps = 23;
          niri.settings._children = [
            {
              output = {
                _args = [ "DP-5" ];
                scale = 2;
              };
            }
            {
              window-rule = {
                match._props.app-id = "^mpv$";
                open-floating = false;
              };
            }
          ];
          niri.settings.hotkey-overlay.skip-at-startup = false;
          dms.settings = {
            matugenTargetMonitor = "eDP-1";
            blurEnabled = false;
            appDrawerSectionViewModes.apps = "grid";
            showDock = false;
            monoFontFamily = "Custom Mono";
            barConfigs = [
              {
                id = "custom";
                rightWidgets = [ "clock" ];
              }
            ];
          };
        };
      } { };
      # Official HM settings are also explicit declarations, not just the
      # feature tree. The same precedence must hold for both entry points.
      direct = home platform true { } {
        wayland.windowManager.niri.settings = {
          input.mouse = {
            left-handed = { };
            accel-speed = 0.6;
          };
          input.touchpad = {
            tap = { };
            natural-scroll = { };
          };
          input.keyboard.xkb.layout = "de";
          layout.gaps = 23;
          binds."Mod+M".spawn = [ "custom-task-manager" ];
          window-rule = {
            match._props.app-id = "^mpv$";
            open-floating = false;
          };
        };
      };
      partial = home platform false {
        desktop.niri.settings.input.touchpad.accel-speed = 0.6;
      } { };
      partialDirect = home platform false { } {
        wayland.windowManager.niri.settings.input.touchpad.accel-speed = 0.6;
      };
      forced = home platform false { } {
        wayland.windowManager.niri.settings = lib.mkForce { layout.gaps = 31; };
      };
      disabledTap = home platform false { } {
        # Niri's tap is a presence-only flag, not a boolean argument. Use the
        # official module's block override to omit it without inventing syntax.
        wayland.windowManager.niri.settings.input.touchpad = lib.mkForce {
          natural-scroll = { };
        };
      };
      bareRules = home platform false { } {
        wayland.windowManager.niri.settings.window-rule = {
          match._props.app-id = "^mpv$";
          open-floating = false;
        };
      };
      layoutOnly = home platform false { } {
        desktop.niri.runtimeIncludes = [
          {
            path = "/home/test/.config/niri/dms/layout.kdl";
            defaultSections = [ "layout" ];
          }
        ];
        wayland.windowManager.niri.settings.input.touchpad.accel-speed = 0.6;
      };
      outputOnly = home platform false { } {
        # Fixture-only fallback, supplied by this test host, never a feature's
        # hardware default. First-match defaults must follow runtime outputs.
        desktop.niri.defaultSettings.output = {
          _args = [ "DP-6" ];
          scale = 1;
        };
        desktop.niri.runtimeIncludes = [
          {
            path = "/home/test/.config/niri/dms/outputs.kdl";
            strategy = "first-wins";
            defaultSections = [ "output" ];
          }
        ];
      };
      # Arch intentionally uses package=null; HM's enableDefaultConfig requires
      # a Nix package with src. Exercise that upstream option on NixOS.
      upstream = home platform true { } {
        wayland.windowManager.niri.enableDefaultConfig = true;
      };
      cases = {
        inherit
          enabled
          custom
          direct
          inactive
          disabled
          partial
          partialDirect
          forced
          disabledTap
          bareRules
          layoutOnly
          outputOnly
          ;
      }
      // lib.optionalAttrs (platform == "nixos") { inherit upstream; };
      niri = enabled.wayland.windowManager.niri;
      dms = enabled.programs.dank-material-shell.settings;
    in
    assert lib.all (cfg: lib.all (a: a.assertion) cfg.assertions) (builtins.attrValues cases);
    assert niri.settings.binds."Mod+D".toggle-overview == { };
    assert !(niri.settings ? input);
    assert niri.settings.hotkey-overlay.skip-at-startup == { };
    assert niri.settings.binds."Mod+Tab".toggle-overview == { };
    assert niri.settings.binds."Mod+T".spawn == enabled.desktop.applications.terminal.command;
    assert !(niri.settings ? spawn-at-startup);
    # Linux installs Chrome through the software plan, without enabling HM's
    # Chrome module. Its shortcut must still use the selected provider.
    assert !enabled.programs.google-chrome.enable;
    assert
      niri.settings.binds."Mod+B".spawn == [
        (enabled.software.resolved.chrome.command "google-chrome-stable")
      ];
    assert niri.settings.binds."Mod+M".spawn == niri.settings.binds."Ctrl+Alt+Delete".spawn;
    assert lib.last niri.settings.binds."Mod+M".spawn == "focusOrToggle";
    assert dms.currentThemeName == "dynamic" && dms.currentThemeCategory == "dynamic";
    assert !(dms ? matugenTargetMonitor) && dms.blurEnabled && dms.blurWallpaperOnOverview;
    assert dms.clockDateFormat == "M 月 dd 日" && dms.appDrawerSectionViewModes.apps == "list";
    assert dms.monoFontFamily == "Maple Mono NF CN" && enabled.software.resolved ? maple-mono;
    assert dms.launcherLogoMode == "os" && dms.showDock && dms.dockGroupByApp;
    assert dms.dockIndicatorStyle == "line" && dms.dockIsolateDisplays;
    assert dms.dockLauncherEnabled && dms.dockLauncherLogoMode == "os";
    assert dms.dockLauncherLogoColorOverride == "primary" && dms.showOnLastDisplay.dock;
    assert dms.appsDockColorizeActive && dms.appsDockActiveColorMode == "success";
    assert builtins.elem "network_speed_monitor" (builtins.head dms.barConfigs).rightWidgets;
    assert !(dms ? screenPreferences) && (builtins.head dms.barConfigs).screenPreferences == [ "all" ];
    assert !(lib.hasInfix "/niri/dms/" disabled.wayland.windowManager.niri.extraConfig);
    assert !(disabled.wayland.windowManager.niri.settings.binds ? "Mod+M");
    assert !(inactive.wayland.windowManager.niri.settings ? spawn-at-startup);
    assert !(inactive.wayland.windowManager.niri.settings.binds ? "Mod+T");
    assert !(inactive.wayland.windowManager.niri.settings.binds ? "Mod+B");
    assert custom.wayland.windowManager.niri.settings.binds."Mod+M".spawn == [ "custom-task-manager" ];
    assert custom.programs.dank-material-shell.settings.matugenTargetMonitor == "eDP-1";
    assert !custom.programs.dank-material-shell.settings.blurEnabled;
    assert custom.programs.dank-material-shell.settings.appDrawerSectionViewModes.apps == "grid";
    assert custom.wayland.windowManager.niri.settings.input.keyboard.xkb.layout == "de";
    assert !custom.wayland.windowManager.niri.settings.hotkey-overlay.skip-at-startup;
    assert !custom.programs.dank-material-shell.settings.showDock;
    assert custom.programs.dank-material-shell.settings.monoFontFamily == "Custom Mono";
    assert map (bar: bar.id) custom.programs.dank-material-shell.settings.barConfigs == [ "custom" ];
    lib.mapAttrsToList (variant: cfg: {
      inherit platform variant;
      source = cfg.xdg.configFile."niri/config.kdl".source;
    }) cases;
  configs = lib.concatMap check [
    "arch"
    "nixos"
  ];
  archHost = (import ../../lib/hosts/load.nix { inherit lib; } (import ../../../hosts/ArchLinux)) // {
    profiles = (import ../fixtures/feature-input.nix { inherit lib; }) (
      allOff
      // {
        niri = true;
        ghostty = true;
        chrome = true;
        mpv = true;
      }
    );
  };
  nativeHost = rawMkHost "ArchHost" archHost;
  nativeEdge = nativeHost.views.home;
  genericHost = home "arch" false { } (
    { pkgs, ... }:
    {
      assertions = [
        {
          assertion = !(pkgs.config.allowUnfreePredicate { pname = "microsoft-edge"; });
          message = "A host-only package must not expand shared license permissions.";
        }
        {
          assertion = pkgs.config.allowUnfreePredicate { pname = "google-chrome"; };
          message = "The shared Chrome feature must retain its existing license permission.";
        }
      ];
    }
  );
  inactiveHost =
    home "arch" false { desktop.niri.settings = archHost.features.desktop.niri.settings; }
      {
        wayland.windowManager.niri.enable = false;
      };
  withoutNiri = home "arch" false {
    desktop.niri = {
      enable = false;
      settings = archHost.features.desktop.niri.settings;
    };
  } { };
  parser = pkgs.niri.overrideAttrs (_: {
    pname = "niri-config-probe";
    outputs = [ "out" ];
    postPatch = ''
      mkdir -p niri-config/examples
      cp ${./niri-config.rs} niri-config/examples/nixconfig.rs
    '';
    buildPhase = ''
      runHook preBuild
      cargo build --offline --locked --release -p niri-config --example nixconfig
      runHook postBuild
    '';
    doCheck = false;
    installPhase = ''
      mkdir -p "$out/bin"
      cp target/release/examples/nixconfig "$out/bin/niri-config-probe"
    '';
    postInstall = "";
    doInstallCheck = false;
  });
in
assert !(nativeEdge.software.resolved ? edge);
assert builtins.elem "microsoft-edge-stable-bin" nativeEdge.software.plan.installations.pacman.aur;
assert
  nativeEdge.wayland.windowManager.niri.settings.binds."Mod+B".spawn
  == [ "/usr/bin/microsoft-edge-stable" ];
assert
  !(builtins.elem "microsoft-edge-stable-bin" genericHost.software.plan.installations.pacman.aur);
assert lib.all (cfg: lib.all (a: a.assertion) cfg.assertions) [
  nativeEdge
  genericHost
];
assert !(nativeHost.configuration.pkgs.config.allowUnfreePredicate { pname = "microsoft-edge"; });
assert !(inactiveHost.software.resolved ? edge);
assert !(withoutNiri.software.resolved ? edge);
assert !(inactiveHost.xdg.configFile ? "niri/config.kdl");
pkgs.runCommand "niri-dms-configuration-check"
  {
    nativeBuildInputs = [
      pkgs.niri
      pkgs.python3
      parser
    ];
  }
  ''
    python - ${pkgs.writeText "niri-test-cases.json" (builtins.toJSON configs)} <<'PY'
    from pathlib import Path
    import json
    import subprocess
    import sys
    import tempfile

    def inspect(config):
        result = subprocess.run(['niri-config-probe', str(config)], check=True,
                                capture_output=True, text=True)
        return dict(line.split('=', 1) for line in result.stdout.splitlines())

    for case in json.loads(Path(sys.argv[1]).read_text()):
        variant = case['variant']
        print(case['platform'], variant, flush=True)
        text = Path(case['source']).read_text()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / 'config.kdl'
            fragments = root / 'dms'
            config.write_text(text.replace('/home/test/.config/niri/dms', str(fragments)))
            command = ['niri', 'validate', '--config', str(config)]
            # A fresh home has none of the generated files yet.
            subprocess.run(command, check=True)
            initial = inspect(config)
            expected_gaps = '31' if variant == 'forced' else ('23' if variant in ('custom', 'direct') else '12')
            assert initial['gaps'] == expected_gaps
            if variant == 'inactive':
                assert initial['startup-count'] == '0'
                assert 'Mod+T' not in initial and 'Mod+B' not in initial
                assert initial['mpv-floating-rules'] == ""
            elif variant != 'forced':
                assert 'Mod+B' in initial
            if variant in ('partial', 'partialDirect', 'layoutOnly'):
                assert initial['touchpad-speed'] == '0.6'
                assert initial['touchpad-tap'] == 'true'
                assert initial['touchpad-natural-scroll'] == 'true'
            if variant == 'forced':
                assert initial['touchpad-tap'] == 'false'
                assert initial['touchpad-natural-scroll'] == 'false'
                assert initial['mpv-floating-rules'] == ""
            if variant == 'disabledTap':
                assert initial['touchpad-tap'] == 'false'
                assert initial['touchpad-natural-scroll'] == 'true'
            if variant == 'bareRules':
                assert initial['mpv-floating-rules'].split(',')[-1] == 'false'
            fragments.mkdir()
            (fragments / 'binds.kdl').write_text('binds { Mod+M { spawn "old-task-manager"; }; }\n')
            (fragments / 'outputs.kdl').write_text('output "DP-5" { scale 1; }\noutput "DP-6" { scale 1.5; }\n')
            (fragments / 'colors.kdl').write_text('layout { focus-ring { active-color "#123456"; }; }\n')
            (fragments / 'layout.kdl').write_text('layout { gaps 4; }\n')
            (fragments / 'input.kdl').write_text('input { mouse { accel-speed -0.2; }; touchpad { accel-speed 0.1; }; keyboard { xkb { layout "us"; }; }; }\n')
            (fragments / 'windowrules.kdl').write_text('window-rule { match app-id="^mpv$"; open-floating true; }\n')
            subprocess.run(command, check=True)
            final = inspect(config)
            if variant != 'forced':
                assert final['DP-5-scale'] == '2'
            if variant in ('disabled', 'partial', 'partialDirect', 'forced', 'disabledTap', 'bareRules'):
                assert final == initial, 'Disabled integration loaded runtime fragments'
                continue
            if variant == 'layoutOnly':
                assert final == {**initial, 'gaps': '4'}, 'Runtime layout changed unrelated settings'
                continue
            if variant == 'outputOnly':
                assert initial['DP-6-scale'] == '1'
                assert final == {**initial, 'DP-6-scale': '1.5'}, 'First-match defaults masked runtime output'
                continue
            assert final['DP-6-scale'] == '1.5'
            if variant in ('custom', 'direct'):
                assert final['gaps'] == '23'
                assert final['mouse-left-handed'] == 'true' and final['mouse-speed'] == '0.6'
                assert final['touchpad-tap'] == 'true' and final['touchpad-natural-scroll'] == 'true'
                assert final['keyboard-layout'] == 'de'
                assert final['mpv-floating-rules'].split(',')[-1] == 'false'
                assert final['Mod+M'] == 'custom-task-manager'
            else:
                assert final['gaps'] == '4', 'Defaults masked runtime layout'
                assert final['mouse-speed'] == '-0.2'
                assert final['touchpad-tap'] == 'false', 'Defaults masked runtime input'
                assert final['keyboard-layout'] == 'us'
                assert final['Mod+M'].endswith('processlist focusOrToggle')
            # Optional includes skip absent files, but must expose invalid existing data.
            (fragments / 'colors.kdl').write_text('not-a-valid-niri-setting\n')
            result = subprocess.run(command, capture_output=True, text=True)
            assert result.returncode != 0, 'Invalid DMS fragment was silently ignored'
    PY
    touch "$out"
  ''
