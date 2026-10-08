{
  config,
  lib,
  user,
  ...
}:
let
  cfg = config.features.smartcard;
in
{
  services.pcscd.enable = lib.mkDefault true;
  security.polkit = lib.mkIf cfg.allowBackgroundAccess {
    enable = lib.mkDefault true;
    extraConfig = import ../../../assets/helpers/common/smartcard-polkit-rule.nix {
      inherit (user) username;
    };
  };
}
