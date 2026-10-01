# Public capability interfaces; upstream ports retain their upstream declarations.
{
  "system.mihomo" = {
    scope = "system";
    module = ./system/services/mihomo.nix;
  };
  "home.gpg" = {
    scope = "home";
    module = ./home/gpg.nix;
  };
  "home.dms" = {
    scope = "home";
    module = ./home/dms.nix;
  };
  "home.noctalia" = {
    scope = "home";
    module = ./home/noctalia.nix;
  };
  "system.noctalia-greeter" = {
    scope = "system";
    module = ./system/services/noctalia-greeter.nix;
  };
  "system.noctalia" = {
    scope = "system";
    module = ./system/services/noctalia.nix;
  };
  "home.niri" = {
    scope = "home";
    module = ./home/niri.nix;
  };
  "home.input-method" = {
    scope = "home";
    module = ./home/input-method.nix;
  };
  "system.smartcard" = {
    scope = "system";
    module = ./system/smartcard.nix;
  };
  "system.chrome" = {
    scope = "system";
    module = ./system/chrome.nix;
  };
  "system.printing" = {
    scope = "system";
    module = ./system/services/printing.nix;
  };
  "system.avahi" = {
    scope = "system";
    module = ./system/services/avahi.nix;
  };
  "system.firmware" = {
    scope = "system";
    module = ./system/services/firmware.nix;
  };
  "system.gnome" = {
    scope = "system";
    module = ./system/services/gnome.nix;
  };
  "system.niri" = {
    scope = "system";
    module = ./system/services/niri.nix;
  };
  "system.dms" = {
    scope = "system";
    module = ./system/services/dms.nix;
  };
  "system.session" = {
    scope = "system";
    module = ./system/services/session.nix;
  };
  "system.network" = {
    scope = "system";
    module = ./system/services/network.nix;
  };
  "system.audio" = {
    scope = "system";
    module = ./system/services/audio.nix;
  };
  "system.bluetooth" = {
    scope = "system";
    module = ./system/services/bluetooth.nix;
  };
  "system.power" = {
    scope = "system";
    module = ./system/services/power.nix;
  };
  "system.storage" = {
    scope = "system";
    module = ./system/services/storage.nix;
  };
}
