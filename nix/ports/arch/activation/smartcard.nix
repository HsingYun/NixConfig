{
  config,
  lib,
  pkgs,
  user,
  ...
}:
let
  cfg = config.services.pcscd;
in
{
  native.activation.nativeSmartcard =
    lib.hm.dag.entryAfter [ "installNativePackages" "linkGeneration" ]
      (
        import ../../../assets/helpers/common/owned-root-file.nix { inherit lib pkgs; } {
          owner = user.username;
          active = config.security.polkit.enable && config.security.polkit.extraConfig != "";
          text = config.security.polkit.extraConfig;
          destination = "/etc/polkit-1/rules.d/60-nixconfig-smartcard-${user.username}.rules";
        }
      );
}
