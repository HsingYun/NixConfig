{ config, lib, ... }: {
  imports = [ ../../../../contracts/system/services/printing.nix ];
  config = lib.mkIf config.services.printing.enable {
    native.requiredPackages = [
      "cups"
      "cups-filters"
      "ghostscript"
      "libusb"
    ];
    native.systemd.units = [ "cups.socket" ];
  };
}
