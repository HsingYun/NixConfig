{ lib, pkgs, ... }:
let
  enable = name: lib.mkEnableOption name;
  bool =
    default:
    lib.mkOption {
      type = lib.types.bool;
      inherit default;
    };
in
{
  options = {
    programs = {
      niri.enable = enable "Niri";
      dms-shell.enable = enable "DMS";
    };
    networking.networkmanager.enable = enable "NetworkManager";
    hardware.bluetooth.enable = enable "Bluetooth";
    security.rtkit.enable = enable "RealtimeKit";
    services = {
      desktopManager.gnome.enable = enable "GNOME";
      displayManager = {
        defaultSession = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        gdm.enable = enable "GDM";
        dms-greeter.enable = enable "DMS greeter";
      };
      greetd = {
        enable = enable "greetd";
        settings = lib.mkOption {
          type = (pkgs.formats.toml { }).type;
          default = { };
        };

      };
      pipewire = {
        enable = enable "PipeWire";
        alsa.enable = bool false;
        pulse.enable = bool false;
      };
      upower.enable = enable "UPower";
      udisks2.enable = enable "UDisks";
      gvfs.enable = enable "GVfs";
    };
  };
}
