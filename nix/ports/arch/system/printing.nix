{ config, lib, ... }:
{
  imports = [ ../../../contracts/system/printing.nix ];
  config = lib.mkMerge [
    (lib.mkIf config.services.printing.enable {
      native.requiredPackages = [
        "cups"
        "cups-filters"
        "ghostscript"
        "libusb"
      ];
      native.systemd.units = [ "cups.socket" ];
    })
    (lib.mkIf config.services.avahi.enable {
      native.requiredPackages = [ "avahi" ];
      native.systemd.units = [
        "avahi-daemon.service"
        "avahi-daemon.socket"
      ];
    })
    (lib.mkIf config.services.fwupd.enable {
      native.requiredPackages = [ "fwupd" ];
      native.systemd.units = [ "fwupd-refresh.timer" ];
    })
    {
      assertions = [
        {
          assertion = !config.services.avahi.nssmdns4;
          message = "Arch port: services.avahi.nssmdns4 is not implemented; configure NSS on the host or disable this option.";
        }
      ];
    }
  ];
}
