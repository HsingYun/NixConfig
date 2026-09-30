{
  config,
  lib,
  pkgs,
  user,
  ...
}:
let
  desktop = config.services.displayManager.defaultSession;
  manager =
    if config.services.displayManager.gdm.enable then
      "gdm"
    else if config.services.greetd.enable then
      "greetd"
    else
      "none";
  greetd = manager == "greetd";
  useDmsGreeter = config.services.displayManager.dms-greeter.enable;
  greeter = if useDmsGreeter then "dms-greeter" else "tuigreet";
  dmsGreeter = import ../../../assets/helpers/common/greeter-session.nix { inherit lib pkgs; } {
    command = "/usr/bin/dms-greeter";
    cacheDir = "/var/cache/dms-greeter";
    inherit desktop;
  };
  greeterCommand =
    if useDmsGreeter then
      "${dmsGreeter}/bin/dms-greeter --command niri --cache-dir /var/cache/dms-greeter -C /etc/greetd/nixconfig-niri.kdl"
    else
      "/usr/bin/tuigreet --time --cmd ${
        lib.escapeShellArg (if desktop == "niri" then "niri-session" else "gnome-session")
      }";
  greetdConfig =
    (pkgs.formats.toml { }).generate "greetd-nixconfig.toml"
      config.services.greetd.settings;
  greetdUnit = pkgs.writeText "greetd-nixconfig.conf" ''
    [Service]
    ExecStart=
    ExecStart=/usr/bin/greetd --config /etc/greetd/nixconfig.toml
  '';
  niriConfig = pkgs.writeText "greeter-niri.kdl" ''
    hotkey-overlay { skip-at-startup; }
    environment { DMS_RUN_GREETER "1"; }
    gestures { hot-corners { off; }; }
    layout { background-color "#000000"; }
  '';
in
{
  config = {
    services.greetd.settings = lib.mkIf greetd {
      terminal.vt = lib.mkDefault 1;
      default_session = {
        command = lib.mkDefault greeterCommand;
        user = lib.mkDefault "greeter";
      };
    };
    native.requiredPackages = lib.optional (manager != "none") manager ++ lib.optional greetd greeter;
    native.activation.selectNativeLoginManager =
      lib.hm.dag.entryAfter [ "installNativePackages" "linkGeneration" ]
        (
          import ../../../assets/helpers/arch/display-manager-activation.nix { inherit lib pkgs; } {
            owner = user.username;
            service = if manager == "none" then null else "${manager}.service";
            files = lib.optionals greetd (
              [
                {
                  source = toString greetdConfig;
                  destination = "/etc/greetd/nixconfig.toml";
                }
                {
                  source = toString greetdUnit;
                  destination = "/etc/systemd/system/greetd.service.d/nixconfig.conf";
                }
              ]
              ++ lib.optional useDmsGreeter {
                source = toString niriConfig;
                destination = "/etc/greetd/nixconfig-niri.kdl";
              }
            );
          }
        );
  };
}
