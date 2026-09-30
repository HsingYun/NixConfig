{ lib }:
let
  service = name: { system, ... }: lib.attrByPath [ "systemd" "services" name "enable" ] false system;
  userService =
    name: { system, ... }: lib.attrByPath [ "systemd" "user" "services" name "enable" ] false system;
  packaged =
    name:
    { system, ... }:
    builtins.elem (toString system.services.${name}.package) (map toString system.systemd.packages);
in
{
  "system.printing" = service "cups";
  "system.avahi" = service "avahi-daemon";
  "system.firmware" = packaged "fwupd";
  "system.network" = service "NetworkManager";
  "system.bluetooth" = service "bluetooth";
  "system.power" = packaged "upower";
  "system.storage" = packaged "udisks2";
  "system.smartcard" = service "pcscd";
  "system.audio" = userService "pipewire-pulse";
  "system.chrome" =
    { system, ... }: system.environment.etc ? "opt/chrome/policies/managed/extra.json";
  "system.gnome" = service "display-manager";
  "system.niri" = service "greetd";
  "system.noctalia-greeter" =
    { system, ... }:
    lib.hasInfix "noctalia-greeter-session" (
      system.services.greetd.settings.default_session.command or ""
    );
  "system.noctalia" = userService "noctalia";
  "system.dms" = userService "dms";
  "system.session" =
    { port, system, ... }:
    (system.services.displayManager.defaultSession or null)
    == (if builtins.elem "system.gnome" port.contracts then "gnome" else "niri");
}
