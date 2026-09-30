{ lib, mkHost }:
let
  allOff = lib.genAttrs (builtins.attrNames
    (import ../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  makeWith =
    preferences: featureConfig: homeConfig:
    (mkHost "ArchDesktop" {
      platform = "arch";
      packageManager = "pacman";
      features = builtins.removeAttrs allOff [
        "launcher"
        "wallpaper"
        "keyring"
        "printing"
        "firmware"
        "fileManager"
      ];
      inherit featureConfig preferences;
      homeConfig = {
        imports = [ homeConfig ];
        home.stateVersion = "26.05";
      };
    }).configuration.config;
  make =
    featureConfig:
    makeWith (lib.optionalAttrs (featureConfig.desktop.niri.enable or false) {
      desktop = "niri";
      loginManager = "greetd";
    }) featureConfig;
  niriOnly = makeWith { } { desktop.niri.enable = true; } { };
  gdmBoth = makeWith {
    desktop = "gnome";
    loginManager = "gdm";
  } { inherit desktop; } { };
  manual = makeWith { loginManager = "none"; } { desktop.niri.enable = true; } { };
  desktop = {
    gnome.enable = true;
    niri.enable = true;
    dms.enable = true;
    wallpaper = {
      image = "/test/wallpaper.png";
      lockImage = "/test/lock.png";
    };
    launcher.hiddenEntries = [
      "vim.desktop"
      "custom.desktop"
    ];
    niri.settings.layout.gaps = 20;
    dms.settings.fontFamily = "Test Sans";
    dms.session.isLightMode = true;
    gnome.settings."org/gnome/desktop/interface".clock-show-seconds = true;
  };
  cfg = make { inherit desktop; } { };
  disabled = make {
    desktop = desktop // {
      wallpaper.enable = false;
      launcher.enable = false;
      fileManager.enable = false;
      gnome = desktop.gnome // {
        flatAppGrid = false;
      };
    };
  } { };
  broken = make { inherit desktop; } { wayland.windowManager.niri.enable = false; };
  native = [
    "niri"
    "dms"
    "gnome-shell"
    "gnome-firmware"
    "gnome-user-themes"
    "gnome-dash-to-dock"
    "gnome-desktop-icons"
    "tela"
    "xwayland-satellite"
    "xdg-desktop-portal-gnome"
    "xdg-desktop-portal-gtk"
    "matugen"
    "cava"
  ];
  gnomeOnly = make { desktop.gnome.enable = true; } { };
  gnomePackages = [
    "mission-center"
    "gdm"
    "gnome-color-manager"
    "gnome-control-center"
    "gnome-disk-utility"
    "gnome-font-viewer"
    "gnome-keyring"
    "gnome-logs"
    "gnome-menus"
    "gnome-session"
    "gnome-settings-daemon"
    "gnome-shell"
    "gnome-system-monitor"
    "gnome-text-editor"
    "loupe"
    "malcontent"
    "nautilus"
    "papers"
    "snapshot"
    "sushi"
    "seahorse"
    "xdg-desktop-portal-gnome"
  ];
  niri = cfg.wayland.windowManager.niri;
  dms = cfg.programs.dank-material-shell;
in
assert lib.assertMsg (lib.all (a: a.assertion) cfg.assertions) (
  lib.concatMapStringsSep "\n" (a: a.message) (lib.filter (a: !a.assertion) cfg.assertions)
);
assert lib.all (name: cfg.software.resolved.${name}.provider == "pacman") native;
# GNOME must install the complete explicit selection even without Niri.
assert lib.all (
  name:
  gnomeOnly.software.resolved.${name}.provider == "pacman"
  && builtins.elem name gnomeOnly.software.plan.installations.pacman.packages
  && lib.count (p: p == name) cfg.software.plan.installations.pacman.packages == 1
) gnomePackages;
assert niriOnly.software.resolved.tuigreet.provider == "pacman";
assert !(niriOnly.software.resolved ? dms-greeter);
assert !(manual.home.activation ? selectNativeLoginManager);
assert !(manual.software.resolved ? greetd);
assert !(gdmBoth.software.resolved ? greetd);
assert lib.hasInfix "enable --force gdm.service"
  gdmBoth.home.activation.selectNativeLoginManager.data;
assert cfg.software.resolved.greetd.provider == "pacman";
assert cfg.software.resolved.dms-greeter.provider == "pacman";
assert lib.hasInfix "enable --force greetd.service"
  cfg.home.activation.selectNativeLoginManager.data;
assert lib.hasInfix "enable --force gdm.service"
  gnomeOnly.home.activation.selectNativeLoginManager.data;
assert !(builtins.elem "gnome" gnomeOnly.software.plan.installations.pacman.packages);
assert
  gnomeOnly.home.activation.selectNativeLoginManager.after == [
    "installNativePackages"
    "linkGeneration"
  ];
assert lib.all (
  p:
  !(builtins.elem (lib.getName p) [
    "niri"
    "dms-shell"
    "quickshell"
    "gnome-shell"
    "tela-icon-theme"
  ])
) cfg.home.packages;
assert
  niri.enable
  && niri.package == null
  && niri.portalPackage == null
  && niri.xwaylandSatellitePackage == null;
assert !niri.systemd.enable && !niri.checkConfig;
assert cfg.software.resolved.xdg-terminal-exec.provider == "pacman";
assert cfg.xdg.terminal-exec.package == null;
assert !lib.any (p: lib.getName p == "xdg-terminal-exec") cfg.home.packages;
assert niri.settings.layout.gaps == 20;
assert
  niri.settings.binds."Mod+Space".spawn == [
    "/usr/bin/dms"
    "ipc"
    "call"
    "spotlight"
    "toggle"
  ];
assert cfg.home.activation.validateArchNiri.after == [ "installNativePackages" ];
assert cfg.programs.gnome-shell.enable && cfg.programs.gnome-shell.extensions == [ ];
assert builtins.elem "dash-to-dock@micxgx.gmail.com" (
  map (v: v.value) cfg.dconf.settings."org/gnome/shell".enabled-extensions.value
);
assert cfg.dconf.settings."org/gnome/desktop/interface".clock-show-seconds;
assert
  cfg.dconf.settings."org/gnome/desktop/background".picture-uri == "file:///test/wallpaper.png";
assert dms.enable && dms.package == null && dms.systemd.enable;
assert !cfg.programs.quickshell.enable;
assert dms.session.wallpaperPath == "/test/wallpaper.png" && dms.session.isLightMode;
assert
  dms.settings.lockScreenWallpaperPath == "/test/lock.png" && dms.settings.fontFamily == "Test Sans";
assert
  cfg.xdg.configFile."systemd/user/dms.service".source
  == cfg.xdg.configFile."systemd/user/niri.service.wants/dms.service".source;
assert !(cfg.xdg.configFile ? "systemd/user/graphical-session.target.wants/dms.service");
assert lib.hasInfix "ConditionEnvironment=XDG_CURRENT_DESKTOP=niri"
  cfg.xdg.configFile."systemd/user/dms.service.d/nixconfig.conf".text;
assert cfg.features.desktop.keyring.enable;
assert cfg.features.desktop.fileManager.enable;
assert niri.settings.binds."Mod+E".spawn == [ "/usr/bin/nautilus" ];
assert cfg.dconf.settings."org/gnome/desktop/app-folders".folder-children.value == [ ];
assert !(niriOnly.dconf.settings ? "org/gnome/desktop/app-folders");
assert !(disabled.dconf.settings ? "org/gnome/desktop/app-folders");
assert !(disabled.dconf.settings ? "org/gnome/nautilus/preferences");
assert !(disabled.software.resolved ? nautilus);
assert !(disabled.wayland.windowManager.niri.settings.binds ? "Mod+E");
assert
  map (v: v.value) disabled.dconf.settings."org/gnome/shell".favorite-apps.value
  == [ "org.gnome.TextEditor.desktop" ];
assert cfg.desktop.launcher.hiddenEntries == desktop.launcher.hiddenEntries;
assert
  cfg.desktop.launcher.nativeRoots == [
    "/usr/local"
    "/usr"
  ];
assert
  disabled.desktop.launcher.hiddenEntries == [ ] && disabled.desktop.launcher.nativeRoots == [ ];
assert disabled.home.activation ? launcherOverrides;
assert !(disabled.programs.dank-material-shell.session ? wallpaperPath);
assert !(disabled.dconf.settings ? "org/gnome/desktop/background");
assert !(builtins.tryEval (builtins.deepSeq broken.assertions true)).success;
{
  nativePackages = native;
  inherit gnomePackages;
  bothDesktops = true;
  scopedDmsService = true;
  structuredSettings = true;
  wallpaper = true;
  hiding = true;
  disabledFeatures = true;
  dependencyValidation = true;
}
