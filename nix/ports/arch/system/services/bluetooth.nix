{ config, lib, ... }: {
  imports = [ ../../../../contracts/system/services/bluetooth.nix ];
  config = lib.mkIf config.hardware.bluetooth.enable {
    native.requiredPackages = [
      "bluez"
      "bluez-utils"
    ];
    native.systemd.units = [ "bluetooth.service" ];
  };
}
