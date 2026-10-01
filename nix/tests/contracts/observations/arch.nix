{ lib }:
let
  packageEffects =
    names:
    { system, ... }:
    lib.genAttrs names (name: builtins.elem name system.native.requiredPackages);
  unitEffects =
    names:
    { system, ... }:
    lib.genAttrs names (name: builtins.elem name system.native.systemd.units);
  service =
    packages: units: cfg:
    packageEffects packages cfg // unitEffects units cfg;
  homeFiles =
    names:
    { home, ... }:
    lib.genAttrs names (name: home.xdg.configFile ? ${name});
in
{
  "system.mihomo" = { system, ... }: {
    package = system.software.resolved ? mihomo;
    unit = builtins.elem "mihomo.service" system.native.systemd.units;
    definition = system.native.systemd.definitions ? "mihomo.service";
  };
  "home.niri" = { home, ... }: {
    nativePackage =
      home.wayland.windowManager.niri.enable && home.wayland.windowManager.niri.package == null;
    nativeValidation = home.home.activation ? validateArchNiri;
  };
  "system.printing" = service [ "cups" "cups-filters" "ghostscript" "libusb" ] [ "cups.socket" ];
  "system.avahi" = service [ "avahi" ] [ "avahi-daemon.service" "avahi-daemon.socket" ];
  "system.firmware" = service [ "fwupd" ] [ "fwupd-refresh.timer" ];
  "system.network" =
    cfg:
    service [ "networkmanager" ] [ "NetworkManager.service" ] cfg
    // {
      waitOnline = builtins.elem "NetworkManager-wait-online.service" cfg.system.native.systemd.enableOnly;
      preflight = cfg.system.native.preflight ? checkNativeDesktopNetwork;
    };
  "system.bluetooth" = service [ "bluez" "bluez-utils" ] [ "bluetooth.service" ];
  # These native services use the packages' DBus activation units.
  "system.power" = packageEffects [ "upower" ];
  "system.storage" = packageEffects [
    "udisks2"
    "gvfs"
  ];
  "system.smartcard" = service [ "pcsclite" "ccid" "polkit" ] [ "pcscd.socket" ];
  "system.audio" =
    cfg:
    packageEffects [ "rtkit" "pipewire" "wireplumber" "pipewire-alsa" "pipewire-pulse" ] cfg
    // homeFiles [
      "systemd/user/pipewire.service"
      "systemd/user/pipewire.socket"
      "systemd/user/wireplumber.service"
      "systemd/user/pipewire-pulse.service"
      "systemd/user/pipewire-pulse.socket"
      "systemd/user/default.target.wants/pipewire-pulse.service"
    ] cfg;
  # The production activation and policy contents are exercised by chrome-policy.
  "system.chrome" = { system, ... }: {
    policy = lib.hasInfix "if true ||" system.native.activation.installChromePolicy.data;
  };
  "system.gnome" = packageEffects [
    "gnome-session"
    "gnome-shell"
    "gdm"
  ];
  "system.niri" = packageEffects [
    "niri"
    "xwayland-satellite"
    "greetd"
  ];
  "system.noctalia-greeter" = { system, ... }: {
    package = builtins.elem "noctalia-greeter" system.native.requiredPackages;
    greeter = lib.hasInfix "noctalia-greeter-session" (
      system.services.greetd.settings.default_session.command or ""
    );
    accounts = builtins.elem "accountsservice" system.native.requiredPackages;
  };
  "home.noctalia" = { home, ... }: { validation = home.home.activation ? validateArchNoctalia; };
  "system.noctalia" = { home, ... }: {
    package = home.software.resolved ? noctalia;
    service = home.systemd.user.services ? noctalia;
  };
  "system.dms" =
    cfg:
    packageEffects [ "dms" "niri" ] cfg
    // {
      userService = cfg.home.xdg.configFile ? "systemd/user/dms.service";
    };
  "system.session" = { port, system, ... }: {
    manager = lib.hasInfix (
      if builtins.elem "system.gnome" port.contracts then "gdm.service" else "greetd.service"
    ) system.native.activation.selectNativeLoginManager.data;
  };
}
