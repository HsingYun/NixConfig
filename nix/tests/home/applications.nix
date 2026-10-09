{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  make =
    provider: extra:
    (mkHost "Applications" {
      platform = "arch";
      features = allOff // {
        niri = true;
        ghostty = true;
        chrome = true;
        fileManager = true;
      };
      homeConfig = {
        imports = [ extra ];
        home.stateVersion = "26.05";
        software.providerOverrides = lib.genAttrs [ "ghostty" "chrome" "xdg-terminal-exec" ] (_: provider);
      };
    }).views.home;
  standaloneWith =
    extra:
    (mkHost "StandaloneTerminal" {
      platform = "arch";
      features = allOff;
      homeConfig = {
        imports = [ extra ];
        home.stateVersion = "26.05";
        desktop.applications.terminal = {
          command = [ "/usr/bin/foot" ];
          desktopId = "foot.desktop";
        };
      };
      packageManager = {
        type = "pacman";
        extraPkg.pacman = {
          packages = [ "foot" ];
          aur = [ "google-chrome" ];
        };
      };
    }).views.home;
  standalone = standaloneWith { };
  commandOnly = standaloneWith { desktop.applications.terminal.desktopId = lib.mkForce null; };
  noTerminal = standaloneWith { desktop.applications.terminal = lib.mkForce null; };
  wsl =
    (mkHost "WslChrome" {
      platform = "nixos-wsl";
      features = allOff // {
        chrome = true;
      };
      homeConfig.home.stateVersion = "26.05";
    }).views.home;
  verify =
    provider:
    let
      enabled = make provider { };
      disabled = make provider {
        programs.ghostty.enable = false;
        xdg.terminal-exec.enable = false;
        desktop.applications.browser = null;
      };
      noRoles = make provider {
        desktop.applications = {
          browser = null;
          terminal = null;
          fileManager = null;
        };
      };
      partial = make provider {
        desktop.applications = {
          browser.desktopId = "custom-browser.desktop";
          terminal.desktopId = null;
          fileManager.appId = null;
        };
      };
      commandField = make provider {
        desktop.applications.terminal.command = [ "/custom/terminal" ];
      };
      replacement = make provider {
        desktop.applications.terminal = {
          command = [
            "/custom/terminal"
            "--flag"
          ];
          desktopId = null;
        };
        desktop.applications.fileManager = {
          command = [ "/custom/files" ];
          desktopId = null;
          appId = null;
        };
      };
      custom = make provider {
        desktop.applications = {
          browser = {
            command = [
              "/custom/browser"
              "--private"
            ];
            desktopId = "custom-browser.desktop";
          };
          terminal = {
            command = [ "/custom/terminal" ];
            desktopId = "custom-terminal.desktop";
          };
          fileManager = null;
        };
      };
      override = make provider {
        wayland.windowManager.niri.settings.binds."Mod+B".spawn = [ "/explicit/browser" ];
      };
      binds = h: h.wayland.windowManager.niri.settings.binds;
    in
    assert lib.all (h: lib.all (a: a.assertion) h.assertions) [
      enabled
      disabled
      noRoles
      partial
      commandField
      replacement
      custom
      override
    ];
    assert (binds enabled)."Mod+T".spawn == enabled.desktop.applications.terminal.command;
    assert !(enabled.wayland.windowManager.niri.settings ? spawn-at-startup);
    assert (binds enabled)."Mod+B".spawn == enabled.desktop.applications.browser.command;
    assert
      (binds enabled)."Mod+Return".spawn
      == [ (enabled.software.resolved.xdg-terminal-exec.command "xdg-terminal-exec") ];
    assert disabled.desktop.applications.terminal == null;
    assert !(disabled.home.sessionVariables ? TERMINAL);
    assert !(disabled.xdg.terminal-exec.settings ? default);
    assert
      !(binds disabled ? "Mod+T") && !(binds disabled ? "Mod+Return") && !(binds disabled ? "Mod+B");
    assert !(disabled.wayland.windowManager.niri.settings ? spawn-at-startup);
    assert !(disabled.xdg.mimeApps.defaultApplications ? "x-scheme-handler/http");
    assert !(disabled.software.resolved ? xdg-terminal-exec);
    assert noRoles.programs.ghostty.enable;
    assert noRoles.software.resolved ? ghostty;
    assert !(noRoles.home.sessionVariables ? TERMINAL);
    assert !(noRoles.wayland.windowManager.niri.settings ? spawn-at-startup);
    assert !(binds noRoles ? "Mod+T") && !(binds noRoles ? "Mod+B") && !(binds noRoles ? "Mod+E");
    # Niri's generic launcher remains independent of any chosen terminal.
    assert (binds noRoles) ? "Mod+Return";
    assert !(noRoles.xdg.terminal-exec.settings ? default);
    assert !(noRoles.xdg.mimeApps.defaultApplications ? "x-scheme-handler/http");
    assert !(noRoles.xdg.mimeApps.defaultApplications ? "inode/directory");
    assert
      (binds custom)."Mod+B".spawn == [
        "/custom/browser"
        "--private"
      ];
    assert
      custom.xdg.mimeApps.defaultApplications."x-scheme-handler/http" == [ "custom-browser.desktop" ];
    assert custom.xdg.terminal-exec.settings.default == [ "custom-terminal.desktop" ];
    assert custom.home.sessionVariables.TERMINAL == "/custom/terminal";
    assert !(binds custom ? "Mod+E");
    assert !(custom.xdg.mimeApps.defaultApplications ? "inode/directory");
    # Leaf overrides preserve sibling policy defaults, including commands.
    assert partial.desktop.applications.browser.command == enabled.desktop.applications.browser.command;
    assert
      partial.xdg.mimeApps.defaultApplications."x-scheme-handler/http" == [ "custom-browser.desktop" ];
    assert
      partial.desktop.applications.terminal.command == enabled.desktop.applications.terminal.command;
    assert partial.home.sessionVariables.TERMINAL == enabled.home.sessionVariables.TERMINAL;
    assert !(partial.xdg.terminal-exec.settings ? default);
    assert
      partial.desktop.applications.fileManager.command
      == enabled.desktop.applications.fileManager.command;
    assert
      partial.xdg.mimeApps.defaultApplications."inode/directory" == [ "org.gnome.Nautilus.desktop" ];
    assert
      !(lib.any (
        rule: (rule.window-rule.match._props.app-id or null) == "^org\\.gnome\\.Nautilus$"
      ) partial.desktop.niri.defaultSettings._children);
    assert (binds commandField)."Mod+T".spawn == [ "/custom/terminal" ];
    assert
      commandField.desktop.applications.terminal.desktopId
      == enabled.desktop.applications.terminal.desktopId;
    # Replacing an application can explicitly clear inherited desktop metadata.
    assert
      (binds replacement)."Mod+T".spawn == [
        "/custom/terminal"
        "--flag"
      ];
    assert (binds replacement)."Mod+E".spawn == [ "/custom/files" ];
    assert !(replacement.xdg.terminal-exec.settings ? default);
    assert !(replacement.xdg.mimeApps.defaultApplications ? "inode/directory");
    assert replacement.desktop.applications.fileManager.appId == null;
    assert (binds override)."Mod+B".spawn == [ "/explicit/browser" ];
    provider;
in
assert import ./application-roles.nix { inherit lib; };
assert lib.all (h: lib.all (a: a.assertion) h.assertions) [
  standalone
  commandOnly
  noTerminal
];
assert commandOnly.home.sessionVariables.TERMINAL == "/usr/bin/foot";
assert !commandOnly.xdg.terminal-exec.enable;
assert !(commandOnly.software.resolved ? xdg-terminal-exec);
assert !(noTerminal.home.sessionVariables ? TERMINAL);
assert !noTerminal.xdg.terminal-exec.enable;
assert !(noTerminal.software.resolved ? xdg-terminal-exec);
assert standalone.software.resolved.xdg-terminal-exec.provider == "pacman";
assert builtins.elem "xdg-terminal-exec" standalone.software.plan.installations.pacman.packages;
assert standalone.xdg.terminal-exec.package == null;
assert !(standalone.software.resolved ? ghostty);
assert standalone.desktop.applications.browser == null;
assert wsl.desktop.applications.browser == null;
assert !(wsl.xdg.mimeApps.defaultApplications ? "x-scheme-handler/http");
map verify [
  "nix"
  "pacman"
]
