{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.smartcard;
  native = config.software.platform == "arch" && config.software.packageManager.type == "pacman";
in
{
  config = lib.mkIf (config.software.platform == "arch") {
    software.requirements = lib.mkIf (native && cfg.enable) (
      lib.genAttrs [ "pcsclite" "ccid" "polkit" ] (_: { })
    );

    assertions = lib.optional (native && cfg.enable) {
      assertion = lib.all (name: config.software.resolved.${name}.provider == "pacman") [
        "pcsclite"
        "ccid"
        "polkit"
      ];
      message = "Arch smartcard integration requires native pcsclite, ccid and polkit packages; Nix package overrides cannot supply host drivers and units.";
    };

    nativeSystemd.units = lib.optional (native && cfg.enable) "pcscd.socket";

    # Keep policy reconciliation present after the feature is disabled. Native
    # packages remain installed; the shared unit adapter reconciles the socket.
    home.activation.nativeSmartcard =
      lib.hm.dag.entryAfter [ "installNativePackages" "linkGeneration" ]
        (
          import ../../../../assets/helpers/owned-root-file.nix { inherit lib pkgs; } {
            owner = config.home.username;
            active = native && cfg.enable && cfg.allowBackgroundAccess;
            text = import ../../../../assets/helpers/smartcard-polkit-rule.nix {
              inherit (config.home) username;
            };
            destination = "/etc/polkit-1/rules.d/60-nixconfig-smartcard-${config.home.username}.rules";
          }
        );
  };
}
