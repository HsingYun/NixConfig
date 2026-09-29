{
  lib,
  mkHost,
  build,
  rawMkHost,
}:
let
  allOff = lib.genAttrs (builtins.attrNames (import ../lib/features/catalog.nix).features) (_: false);
  arch =
    featureConfig: homeConfig:
    (mkHost "ExperienceArch" {
      platform = "arch";
      packageManager = "pacman";
      features = allOff;
      inherit featureConfig;
      homeConfig = {
        imports = [ homeConfig ];
        home.stateVersion = "26.05";
      };
      preferences = lib.optionalAttrs (featureConfig.desktop.niri.enable or false) {
        desktop = "niri";
        loginManager = "greetd";
      };
    }).configuration.config;
  chinese = arch {
    desktop.gnome.enable = true;
    chinese.enable = true;
  } { };
  allDesktop =
    desktop: dms:
    build {
      features = allOff // {
        gnome = true;
        niri = true;
        inherit dms;
      };
      preferences = {
        inherit desktop;
        loginManager = "greetd";
      };
    };
  nativeOverride = arch { desktop.niri.enable = true; } (
    { pkgs, ... }: { software.packageOverrides.niri = pkgs.niri; }
  );
  keyringOverride = arch { desktop.keyring.enable = true; } (
    { pkgs, ... }: { software.packageOverrides.gnome-keyring = pkgs.gnome-keyring; }
  );
  nixosKeyring = build {
    features = allOff // {
      keyring = true;
    };
    homeConfig = { pkgs, ... }: {
      software.packageOverrides.gnome-keyring = pkgs.gnome-keyring.override { useWrappedDaemon = false; };
    };
  };
  rejects =
    cfg:
    let
      result = builtins.tryEval (lib.all (a: a.assertion) cfg.assertions);
    in
    !result.success || !result.value;
  migration = arch { } (
    { pkgs, ... }: {
      software.packageOverrides.htop = pkgs.htop;
      software.requirements.htop = { };
    }
  );
  inactiveMigration = arch { mpv.enable = true; } (
    { pkgs, ... }: {
      software.packageOverrides.mpv = pkgs.mpv;
      programs.mpv.enable = false;
    }
  );
  host = name: (rawMkHost name (import (../../hosts + "/${name}"))).configuration.config;
  pc = host "NixOS-PC";
  pad = host "NixOS-Pad";
  native = host "ArchLinux";
  wsl = host "NixOS-WSL";
  mac = host "Darwin";
  homes = [
    pc.home-manager.users.test
    pad.home-manager.users.test
    native
  ];
in
assert !(builtins.tryEval (rawMkHost "UnsupportedLinux" { platform = "linux"; }).output).success;
assert lib.all
  (
    home:
    !(home.home.activation ? installChromePolicy)
    && !(home.home.activation ? nativeSmartcard)
    && !(home.home.activation ? nativeSystemd)
    && !(home.home.activation ? removeReplacedNativePackages)
    && !(home.home.activation ? launcherOverrides)
  )
  [
    pc.home-manager.users.test
    pad.home-manager.users.test
    wsl.home-manager.users.test
    mac.home-manager.users.test
  ];
assert pc.home-manager.users.test.xdg.dataFile.applications.recursive;
assert native.software.platform == "arch";
assert lib.all (a: a.assertion) chinese.assertions;
assert builtins.isString chinese.home.activationPackage.drvPath;
assert lib.all (name: chinese.software.resolved.${name}.provider == "pacman") [
  "fcitx5"
  "fcitx5-rime"
  "fcitx5-gtk"
  "fcitx5-qt"
  "rime-ice"
  "gnome-kimpanel"
];
assert
  lib.toList chinese.systemd.user.services.fcitx5-daemon.Service.ExecStart == [ "/usr/bin/fcitx5" ];
assert !(chinese.home.sessionVariables ? GTK_IM_MODULE);
assert builtins.elem "NetworkManager.service" chinese.nativeSystemd.units;
assert builtins.elem "bluetooth.service" chinese.nativeSystemd.units;
assert chinese.software.resolved.pipewire-pulse.provider == "pacman";
assert chinese.xdg.configFile ? "systemd/user/pipewire.service.wants/wireplumber.service";
assert chinese.home.activation.checkNativeDesktopNetwork.before == [ "writeBoundary" ];
assert chinese.dconf.settings ? "org/gnome/settings-daemon/plugins/xsettings";
assert lib.hasInfix "GNOME" chinese.home.sessionVariablesExtra;
assert
  rejects nativeOverride && rejects keyringOverride && rejects nixosKeyring.home-manager.users.test;
assert lib.all
  (
    dms:
    lib.hasInfix "gnome-session" (allDesktop "gnome" dms)
    .services.greetd.settings.default_session.command
  )
  [
    false
    true
  ];
assert (allDesktop "niri" true).services.displayManager.dms-greeter.enable;
assert !(allDesktop "niri" true).security.pam.services.greetd.enableGnomeKeyring;
assert !(allDesktop "niri" false).security.pam.services.greetd.enableGnomeKeyring;
assert pc.security.pam.services.greetd.enableGnomeKeyring;
assert pad.security.pam.services.gdm-password.enableGnomeKeyring;
assert !(pad.security.pam.services ? greetd);
assert lib.all (home: home.home.activation ? initializeVscode) homes;
assert lib.hasInfix "/Library/Application Support/Code/User/settings.json"
  mac.home-manager.users.test.home.activation.initializeVscode.data;
assert lib.hasInfix "/.config/Code/User/settings.json" native.home.activation.initializeVscode.data;
assert lib.hasInfix "niri-session"
  (allDesktop "niri" false).services.greetd.settings.default_session.command;
assert lib.hasInfix "htop" migration.home.activation.removeReplacedNativePackages.data;
assert
  migration.home.activation.removeReplacedNativePackages.after == [
    "installPackages"
    "installNativePackages"
  ];
assert !(migration.xdg.dataFile ? applications);
assert !(inactiveMigration.home.activation ? removeReplacedNativePackages);
assert lib.all (
  home:
  home.features.chinese.enable
  && home.features.commonTools.enable
  && home.features.devel.enable
  && home.features.codex.enable
  && home.features.ghostty.enable
  && home.features.mpv.enable
) homes;
assert
  pc.services.displayManager.defaultSession == "niri" && pc.services.desktopManager.gnome.enable;
assert native.features.desktop.niri.enable && native.features.desktop.gnome.enable;
assert
  pad.services.displayManager.defaultSession == "gnome" && pad.services.displayManager.gdm.enable;
assert pad.home-manager.users.test.features.desktop.screenRotate.enable;
assert
  !wsl.home-manager.users.test.features.chinese.enable
  && !wsl.home-manager.users.test.i18n.inputMethod.enable;
assert
  wsl.home-manager.users.test.features.devel.enable
  && wsl.home-manager.users.test.features.codex.enable;
assert
  mac.home-manager.users.test.features.commonTools.enable
  && mac.home-manager.users.test.features.mpv.enable;
{
  nativeChinese = true;
  systemPackageOverridesRejected = true;
  selectedLoginSession = true;
  explicitProviderMigration = true;
  hostExperience = true;
}
