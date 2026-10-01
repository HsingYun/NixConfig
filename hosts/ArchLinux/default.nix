{ lib, profile, ... }:
{
  platform = "arch";
  packageManager = {
    type = "pacman";
    extraPkg = {
      pacman = {
        aur = [ "microsoft-edge-stable-bin" ];
      };
    };
  };
  system = "x86_64-linux";
  features = lib.recursiveUpdate profile.linuxDesktop {
    desktop = {
      dms = {
        settings = {
          matugenTargetMonitor = "DP-5";
          screenPreferences = {
            dock = [
              {
                name = "DP-4";
                model = "DELL U2518D";
              }
            ];
          };
        };
      };
      niri = {
        settings = {
          _children = [
            # Machine-specific outputs; positions use logical pixels after scaling.
            {
              output = {
                _args = [ "DP-4" ];
                mode = "2560x1440@59.951";
                scale = 1.5;
                position._props = {
                  x = 0;
                  y = 0;
                };
              };
            }
            {
              output = {
                _args = [ "DP-5" ];
                mode = "3840x2160@143.996";
                scale = 2;
                position._props = {
                  x = 0;
                  y = 960;
                };
                focus-at-startup = { };
              };
            }
          ];
        };
      };
    };
  };
  homeConfig = ./home.nix;
}
