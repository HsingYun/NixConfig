{
  config,
  lib,
  osConfig,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.wayland.windowManager.niri;
  native = cfg.package == null;
  upstream = import "${inputs.home-manager}/modules/services/window-managers/niri.nix" {
    inherit lib pkgs;
    config =
      if native then
        config
        // {
          wayland = config.wayland // {
            windowManager = config.wayland.windowManager // {
              niri = cfg // {
                systemd = cfg.systemd // {
                  enable = false;
                };
              };
            };
          };
        }
      else
        config;
  };
in
{
  disabledModules = [ "services/window-managers/niri.nix" ];
  inherit (upstream) imports options;
  config = lib.mkMerge [
    upstream.config
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = osConfig.programs.niri.enable;
          message = "Arch Niri user configuration requires the native system session through programs.niri.enable.";
        }
      ];
      # The host owns the runtime, units and portal integration. Home Manager
      # still owns its upstream Niri option schema and configuration generator.
      wayland.windowManager.niri = {
        package = null;
        systemd.enable = lib.mkDefault false;
        portalPackage = null;
        checkConfig = lib.mkDefault false;
        xwaylandSatellitePackage = null;
      };
    })
    (lib.mkIf (cfg.enable && native && cfg.systemd.enable) {
      # Match HM's unit-installation interface: expose the vendor units in the
      # data directory, without enabling, starting or restarting a compositor.
      # niri-session owns its lifecycle; the system port owns the native runtime.
      xdg.dataFile =
        lib.genAttrs
          [
            "systemd/user/niri.service"
            "systemd/user/niri-shutdown.target"
          ]
          (name: {
            source = config.lib.file.mkOutOfStoreSymlink (
              "${config.native.systemd.user.vendorDirectory}/${baseNameOf name}"
            );
          });
    })
  ];
}
