{ profile, helpers, ... }:
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
  stateVersion.home = "26.05";
  profiles = profile.linuxDesktop;
  features = {
    desktop = {
      autostart = {
        enable = true;
        entries.terminal.application = "terminal";
      };
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
          binds."Mod+B".spawn = [ "/usr/bin/microsoft-edge-stable" ];
        }
        // helpers.kdl.children [
          (helpers.kdl.node "output" [ "DP-4" ] {
            mode = "2560x1440@59.951";
            scale = 1.5;
            position = helpers.kdl.props {
              x = 0;
              y = 0;
            };
          })
          (helpers.kdl.node "output" [ "DP-5" ] {
            mode = "3840x2160@143.996";
            scale = 2;
            position = helpers.kdl.props {
              x = 0;
              y = 960;
            };
            focus-at-startup = { };
          })
        ];
      };
    };
  };
}
