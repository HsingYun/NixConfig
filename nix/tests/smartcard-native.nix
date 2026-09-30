{
  lib,
  mkHost,
  build,
}:
let
  allOff = lib.genAttrs (builtins.attrNames
    (import ../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  arch =
    features: manager:
    (mkHost "SmartcardArch" {
      platform = "arch";
      packageManager = manager;
      features = allOff;
      featureConfig = features;
      homeConfig.home.stateVersion = "26.05";
    }).configuration.config;
  enabled = arch {
    smartcard.enable = true;
    gpg.enable = true;
  } "pacman";
  wsl = arch {
    smartcard = {
      enable = true;
      allowBackgroundAccess = true;
    };
    gpg.enable = true;
  } "pacman";
  disabled = arch { } "pacman";
  nixOnly = arch { } "nix";
  unsupported = arch { smartcard.enable = true; } "nix";
  nixos =
    background:
    build {
      features = allOff // {
        smartcard = true;
      };
      featureConfig.smartcard.allowBackgroundAccess = background;
      # Also exercise external GPG, without the repository's GPG feature.
      homeConfig.programs.gpg.enable = true;
    };
  normalSystem = nixos false;
  remoteSystem = nixos true;
in
assert lib.all (a: a.assertion) (enabled.assertions ++ wsl.assertions ++ nixOnly.assertions);
assert !(builtins.tryEval (builtins.deepSeq unsupported.assertions true)).success;
assert lib.all (name: enabled.software.resolved.${name}.provider == "pacman") [
  "pcsclite"
  "ccid"
  "polkit"
];
assert !enabled.features.smartcard.allowBackgroundAccess;
assert enabled.programs.gpg.scdaemonSettings.disable-ccid;
assert !(enabled.programs.gpg.scdaemonSettings ? pcsc-driver);
assert wsl.features.smartcard.allowBackgroundAccess;
assert builtins.elem "pcscd.socket" enabled.nativeSystemd.units;
assert disabled.nativeSystemd.units == [ ];
assert !(disabled.software.resolved ? pcsclite);
# Cleanup remains available after changing package manager or disabling the feature.
assert nixOnly.home.activation ? nativeSmartcard;
assert normalSystem.services.pcscd.enable;
assert normalSystem.home-manager.users.test.programs.gpg.scdaemonSettings.disable-ccid;
assert !(lib.hasInfix "org.debian.pcsc-lite" normalSystem.security.polkit.extraConfig);
assert remoteSystem.security.polkit.enable;
assert lib.hasInfix ''subject.user === "test"'' remoteSystem.security.polkit.extraConfig;
assert lib.hasInfix "org.debian.pcsc-lite.access_card" remoteSystem.security.polkit.extraConfig;
assert lib.hasInfix "org.debian.pcsc-lite.access_pcsc" remoteSystem.security.polkit.extraConfig;
assert !(lib.hasInfix "isInGroup" remoteSystem.security.polkit.extraConfig);
{
  arch = true;
  archWsl = true;
  retainedNativeResources = true;
  explicitBackgroundAuthorization = true;
  nixosExternalGpg = true;
}
