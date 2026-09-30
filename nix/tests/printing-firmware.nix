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
    features:
    (mkHost "ArchServices" {
      platform = "arch";
      packageManager = "pacman";
      features = allOff // features;
      homeConfig.home.stateVersion = "26.05";
    }).configuration.config;
  printing = arch { printing = true; };
  firmware = arch { firmware = true; };
  disabled = arch { };
  defaults =
    desktop:
    build {
      features =
        builtins.removeAttrs allOff [
          "printing"
          "firmware"
        ]
        // {
          ${desktop} = true;
        };
    };
in
assert lib.all (a: a.assertion) (printing.assertions ++ firmware.assertions ++ disabled.assertions);
assert lib.all (name: printing.software.resolved.${name}.provider == "pacman") [
  "cups"
  "cups-filters"
  "ghostscript"
  "libusb"
  "avahi"
];
assert builtins.elem "cups.socket" printing.nativeSystemd.units;
assert builtins.elem "avahi-daemon.service" printing.nativeSystemd.units;
assert builtins.elem "avahi-daemon.socket" printing.nativeSystemd.units;
assert !(printing.software.resolved ? fwupd);
assert firmware.software.resolved.fwupd.provider == "pacman";
assert firmware.software.resolved.gnome-firmware.provider == "pacman";
assert firmware.nativeSystemd.units == [ "fwupd-refresh.timer" ];
assert !(firmware.software.resolved ? cups);
assert disabled.nativeSystemd.units == [ ];
assert disabled.home.activation ? nativeSystemd;
assert !(disabled.software.resolved ? cups) && !(disabled.software.resolved ? fwupd);
assert lib.all
  (
    desktop:
    let
      cfg = defaults desktop;
    in
    cfg.services.printing.enable && cfg.services.avahi.enable && cfg.services.fwupd.enable
  )
  [
    "gnome"
    "niri"
    "dms"
  ];
{
  arch = true;
  independentServices = true;
  desktopDefaults = true;
  disabledNativePackagesRetained = true;
}
