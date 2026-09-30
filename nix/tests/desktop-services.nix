{
  lib,
  build,
  mkHost,
}:
let
  allOff = lib.genAttrs (builtins.attrNames
    (import ../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  browserTypes = [
    "text/html"
    "application/xhtml+xml"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
  ];
  usesChrome =
    home:
    home.xdg.mimeApps.enable
    && lib.all (
      type: home.xdg.mimeApps.defaultApplications.${type} == [ "google-chrome.desktop" ]
    ) browserTypes;
  execStart =
    home:
    lib.concatStringsSep " " (lib.toList home.systemd.user.services.gnome-keyring.Service.ExecStart);
  desktopCases =
    map
      (
        desktop:
        let
          cfg = build {
            features = (builtins.removeAttrs allOff [ "keyring" ]) // {
              ${desktop} = true;
            };
          };
          home = cfg.home-manager.users.test;
          unit = home.systemd.user.services.gnome-keyring;
        in
        assert lib.all (a: a.assertion) (cfg.assertions ++ cfg.home-manager.users.test.assertions);
        assert cfg.services.gnome.gnome-keyring.enable;
        assert home.features.desktop.keyring.enable;
        assert builtins.elem "graphical-session-pre.target" unit.Install.WantedBy;
        assert builtins.elem "graphical-session-pre.target" unit.Unit.PartOf;
        assert lib.hasInfix "--components=pkcs11,secrets" (execStart home);
        assert !(cfg.systemd.user.services ? gnome-keyring-daemon);
        assert home.services.gnome-keyring.enable;
        assert !(home.systemd.user.services ? gnome-keyring-daemon);
        desktop
      )
      [
        "gnome"
        "niri"
      ];
  disabled = build {
    features = allOff // {
      niri = true;
    };
    featureConfig.desktop.keyring.enable = false;
  };
  console = build { features = allOff; };
  chrome = build {
    features = allOff // {
      chrome = true;
    };
    systemConfig.nixpkgs.config.allowUnfree = true;
  };
  customBrowser = build {
    features = allOff // {
      chrome = true;
    };
    homeConfig.xdg.mimeApps.defaultApplications = lib.genAttrs browserTypes (_: [ "firefox.desktop" ]);
  };
  arch =
    (mkHost "ArchDesktopTest" {
      featureConfig.desktop.keyring.enable = true;
      platform = "arch";
      packageManager = "pacman";
      features = allOff // {
        chrome = true;
      };
      homeConfig = ../../hosts/ArchLinux/home.nix;
    }).configuration.config;
  nativeFiles = arch.xdg.configFile;
  nixHome =
    (mkHost "NixDesktopTest" {
      featureConfig.desktop.keyring.enable = true;
      platform = "arch";
      packageManager = "nix";
      features = allOff;
      homeConfig = {
        home.stateVersion = "26.05";
      };
    }).configuration.config;
  archDisabled =
    (mkHost "ArchDisabledTest" {
      platform = "arch";
      packageManager = "pacman";
      features = allOff;
      homeConfig = {
        home.stateVersion = "26.05";
      };
    }).configuration.config;
  bitwarden = "nngceckbapebfimnlniiiahkandclblb";
  policyPath = "opt/chrome/policies/managed/extra.json";
  noExtensions = build {
    features = allOff // {
      chrome = true;
    };
    featureConfig.chrome.extensions = [ ];
  };
  darwin =
    (mkHost "DarwinChromeTest" {
      platform = "darwin";
      features = allOff // {
        chrome = true;
      };
      systemConfig.system.stateVersion = 6;
      homeConfig.home.stateVersion = "26.05";
    }).configuration.config;
  macHome = darwin.home-manager.users.test;
in
assert !console.services.gnome.gnome-keyring.enable;
assert !(console.systemd.user.services ? gnome-keyring-daemon);
assert !disabled.services.gnome.gnome-keyring.enable;
assert !(disabled.home-manager.users.test.systemd.user.services ? gnome-keyring-daemon);
assert !disabled.home-manager.users.test.services.gnome-keyring.enable;
assert !(disabled.home-manager.users.test.systemd.user.services ? gnome-keyring);
assert !console.home-manager.users.test.xdg.mimeApps.enable;
assert usesChrome chrome.home-manager.users.test;
assert lib.all (
  type:
  customBrowser.home-manager.users.test.xdg.mimeApps.defaultApplications.${type}
  == [ "firefox.desktop" ]
) browserTypes;
assert lib.all (a: a.assertion) arch.assertions;
assert usesChrome arch;
assert arch.software.resolved.gnome-keyring.provider == "pacman";
assert builtins.elem "gnome-keyring" arch.software.plan.installations.pacman.packages;
assert !arch.services.gnome-keyring.enable;
assert !(arch.systemd.user.services ? gnome-keyring);
assert !(arch.systemd.user.services ? gnome-keyring-daemon);
assert !archDisabled.features.desktop.keyring.enable;
assert !(archDisabled.software.requirements ? gnome-keyring);
assert !(archDisabled.xdg.configFile ? "systemd/user/gnome-keyring-daemon.service");
assert lib.all (a: a.assertion) nixHome.assertions;
assert nixHome.software.resolved.gnome-keyring.provider == "nix";
assert lib.hasPrefix (toString nixHome.software.resolved.gnome-keyring.package) (execStart nixHome);
assert !(nixHome.xdg.configFile ? "systemd/user/gnome-keyring-daemon.socket");
assert
  nativeFiles."systemd/user/gnome-keyring-daemon.service".source
  == nativeFiles."systemd/user/default.target.wants/gnome-keyring-daemon.service".source;
assert
  nativeFiles."systemd/user/gnome-keyring-daemon.socket".source
  == nativeFiles."systemd/user/sockets.target.wants/gnome-keyring-daemon.socket".source;
assert arch.features.chrome.extensions == [ bitwarden ];
assert lib.hasInfix "/etc/opt/chrome/policies/managed/nixconfig-extensions.json"
  arch.home.activation.installChromePolicy.data;
assert chrome.programs.chromium.enable;
assert
  (builtins.fromJSON chrome.environment.etc.${policyPath}.text)
  .ExtensionSettings.${bitwarden}.installation_mode == "normal_installed";
assert !(chrome.environment.etc ? "opt/chrome/policies/managed/nixconfig-extensions.json");
assert macHome.programs.google-chrome.enable && macHome.programs.google-chrome.package == null;
assert !(noExtensions.environment.etc ? ${policyPath});
assert !(console.environment.etc ? ${policyPath});
assert lib.all (a: a.assertion) (darwin.assertions ++ macHome.assertions);
assert
  (builtins.fromJSON
    macHome.home.file."Library/Application Support/Google/Chrome/External Extensions/${bitwarden}.json".text
  ).external_update_url == "https://clients2.google.com/service/update2/crx";
assert !macHome.features.desktop.keyring.enable;
assert !(macHome.home.activation ? installChromePolicy);
assert !macHome.xdg.mimeApps.enable;
{
  desktops = desktopCases;
  archNativeUnits = true;
  browserDefaults = true;
  browserOverride = true;
  disabledKeyring = true;
  standaloneNixKeyring = true;
  bitwarden = true;
  disabledExtensions = true;
}
