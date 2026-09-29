{ config, lib, ... }:
let
  cfg = config.features.desktop;
  packages =
    lib.optionals cfg.printing.enable [
      "cups"
      "cups-filters"
      "ghostscript"
      "libusb"
      "avahi"
    ]
    ++ lib.optional cfg.firmware.enable "fwupd";
  units =
    lib.optionals cfg.printing.enable [
      "cups.socket"
      "avahi-daemon.service"
      "avahi-daemon.socket"
    ]
    ++ lib.optional cfg.firmware.enable "fwupd-refresh.timer";
in
{
  config = lib.mkIf (config.software.platform == "arch" && packages != [ ]) {
    assertions = [
      {
        assertion = config.software.packageManager.type == "pacman";
        message = "Standalone printing and firmware services require the Arch pacman adapter.";
      }
      {
        assertion = lib.all (name: config.software.resolved.${name}.provider == "pacman") packages;
        message = "Arch printing and firmware services require native host packages; Nix overrides cannot supply their system units and drivers.";
      }
    ];
    software.requirements = lib.genAttrs packages (_: { });
    nativeSystemd.units = units;
  };
}
