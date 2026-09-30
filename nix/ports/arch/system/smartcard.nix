{ config, lib, ... }:
{
  imports = [ ../../../contracts/system/smartcard.nix ];
  config = lib.mkMerge [
    (lib.mkIf config.services.pcscd.enable {
      native.requiredPackages = [
        "pcsclite"
        "ccid"
        "polkit"
      ];
      native.systemd.units = [ "pcscd.socket" ];
    })
    (lib.mkIf config.security.polkit.enable { native.requiredPackages = [ "polkit" ]; })
  ];
}
