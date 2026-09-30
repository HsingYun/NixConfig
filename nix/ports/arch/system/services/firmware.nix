{ config, lib, ... }: {
  imports = [ ../../../../contracts/system/services/firmware.nix ];
  config = lib.mkIf config.services.fwupd.enable {
    native.requiredPackages = [ "fwupd" ];
    native.systemd.units = [ "fwupd-refresh.timer" ];
  };
}
