{ lib, mkHost }:
let
  catalog = import ../../lib/features/catalog.nix { inherit lib; };
  allOff = lib.genAttrs (builtins.attrNames catalog.features) (_: false);
  make =
    platform: features: systemConfig: homeConfig:
    let
      host =
        (mkHost "Contract" {
          inherit platform features;
          hardwareConfig =
            if platform == "nixos" then
              {
                boot.initrd.enable = false;
                boot.kernel.enable = false;
                boot.loader.grub.enable = false;
              }
            else
              null;
          systemConfig = {
            imports = [ systemConfig ];
          }
          // lib.optionalAttrs (platform != "arch") {
            system.stateVersion = if platform == "darwin" then 6 else "26.11";
          };
          homeConfig = {
            imports = [ homeConfig ];
            home.stateVersion = "26.05";
          };
        }).configuration;
    in
    {
      system = if platform == "arch" then host.systemConfiguration.config else host.config;
      home = if platform == "arch" then host.config else host.config.home-manager.users.test;
    };
  valid = cfg: lib.all (a: a.assertion) (cfg.system.assertions ++ cfg.home.assertions);
  contract =
    platform:
    let
      direct = make platform (allOff // { gpg = true; }) {
        services.printing.enable = true;
        services.avahi.enable = true;
        services.pcscd.enable = true;
      } { programs.gpg.enable = true; };
      disabled =
        make platform
          (
            allOff
            // {
              printing = true;
              smartcard = true;
              gpg = true;
            }
          )
          {
            services.printing.enable = false;
            services.pcscd.enable = false;
          }
          { programs.gpg.enable = true; };
      shared =
        make platform
          (
            allOff
            // {
              printing = true;
              gnome = true;
            }
          )
          {
            services.printing.enable = false;
          }
          { };
    in
    assert valid direct && valid disabled && valid shared;
    assert direct.system.services.printing.enable && direct.system.services.pcscd.enable;
    assert direct.home.programs.gpg.scdaemonSettings.disable-ccid;
    assert !disabled.system.services.printing.enable && !disabled.system.services.pcscd.enable;
    assert !(disabled.home.programs.gpg.scdaemonSettings.disable-ccid or false);
    assert shared.system.services.avahi.enable;
    assert
      platform != "arch"
      || (
        builtins.elem "cups.socket" direct.system.native.systemd.units
        && !(builtins.elem "cups.socket" shared.system.native.systemd.units)
        && builtins.elem "avahi-daemon.service" shared.system.native.systemd.units
        && !(disabled.home.software.resolved ? pcsclite)
      );
    platform;
  dependencies =
    name: [ name ] ++ lib.concatMap dependencies (catalog.features.${name}.requires or [ ]);
  independent =
    platform: name:
    let
      cfg = make platform (allOff // lib.genAttrs (dependencies name) (_: true)) { } { };
    in
    assert lib.assertMsg (valid cfg) "Feature contract failed: ${platform}/${name}";
    # Force actual module configuration, not just catalog resolution.
    assert builtins.isString cfg.home.home.activationPackage.drvPath;
    name;
  perPlatform = lib.genAttrs [ "arch" "darwin" ] (
    platform:
    map (independent platform) (
      builtins.attrNames (
        lib.filterAttrs (_: entry: builtins.elem platform entry.platforms) catalog.features
      )
    )
  );
  inputDirect = make "arch" allOff { } {
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.settings.globalOptions.Hotkey.TriggerKeys = "Control+space";
    };
  };
  inputDisabled = make "arch" (allOff // { chinese = true; }) { } {
    i18n.inputMethod.enable = false;
  };
  native = make "arch" allOff { } { };
  override = make "arch" (allOff // { vim = true; }) {
    software.providerOverrides.vim = "nix";
  } { };
  migration = make "arch" allOff { } (
    { pkgs, ... }: {
      software.packageOverrides.htop = pkgs.htop;
    }
  );
  explicitMigration =
    make "arch" allOff
      {
        software.migration.removeReplaced = [ "htop" ];
      }
      (
        { pkgs, ... }: {
          software.packageOverrides.htop = pkgs.htop;
        }
      );
  missing = make "arch" allOff { services.printing.unsupported = true; } { };
  brokenDependency =
    make "arch"
      (
        allOff
        // {
          niri = true;
          dms = true;
        }
      )
      {
        programs.niri.enable = false;
      }
      { };
in
assert valid inputDirect && valid inputDisabled;
assert inputDirect.home.systemd.user.services ? fcitx5-daemon;
assert inputDirect.home.xdg.configFile ? "fcitx5/config";
assert inputDirect.home.software.resolved.fcitx5.provider == "pacman";
assert !(inputDisabled.home.systemd.user.services ? fcitx5-daemon);
assert !(inputDisabled.home.software.resolved ? fcitx5);
assert native.system.software.plan.report == native.home.software.plan.report;
assert valid override && override.home.software.resolved.vim.provider == "nix";
assert override.home.software.resolved.vim.reason == "explicit provider override";
assert !(migration.home.home.activation ? removeReplacedNativePackages);
assert builtins.elem "systemProfile"
  explicitMigration.home.home.activation.removeReplacedNativePackages.after;
assert builtins.elem "installPackages"
  explicitMigration.home.home.activation.removeReplacedNativePackages.after;
assert !(builtins.tryEval (builtins.deepSeq missing.system.services true)).success;
assert !(builtins.tryEval (builtins.deepSeq brokenDependency.home.assertions true)).success;
{
  sharedServiceContract = map contract [
    "nixos"
    "arch"
  ];
  independentFeatures = perPlatform;
  oneSoftwarePlan = true;
  explicitProviderSelection = true;
  noImplicitSystemRemoval = true;
  unsupportedOptionsRejected = true;
  systemDependenciesChecked = true;
}
