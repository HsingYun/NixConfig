{
  config,
  lib,
  pkgs,
  featureSelection,
  ...
}:
let
  selected = featureSelection;
  enabled.dms = config.features.desktop.dms.enable;
  manager = selected.loginManager;
  greetd = manager == "greetd";
  desktop =
    if selected.desktop != null then
      selected.desktop
    else if enabled.dms then
      "niri"
    else
      null;
  useDmsGreeter = enabled.dms && desktop == "niri";
  sessionCommand =
    if desktop == "gnome" then
      "env XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=GNOME /usr/bin/gnome-session --session=gnome"
    else
      "niri-session";
  dmsGreeter = import ../../../../assets/helpers/greeter-session.nix { inherit lib pkgs; } {
    command = "/usr/bin/dms-greeter";
    cacheDir = "/var/cache/dms-greeter";
    inherit desktop;
  };
  greeterCommand =
    if useDmsGreeter then
      "${dmsGreeter}/bin/dms-greeter --command niri --cache-dir /var/cache/dms-greeter -C /etc/greetd/nixconfig-niri.kdl"
    else
      "/usr/bin/tuigreet --time --cmd ${lib.escapeShellArg sessionCommand}";
  greetdConfig = pkgs.writeText "greetd-nixconfig.toml" ''
    [terminal]
    vt = 1
    [default_session]
    command = ${builtins.toJSON greeterCommand}
    user = "greeter"
  '';
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
  config = lib.mkIf (config.software.platform == "arch" && manager != "none") {
    assertions = [
      {
        assertion = lib.all (name: config.software.resolved.${name}.provider == "pacman") (
          [ manager ] ++ lib.optional greetd (if useDmsGreeter then "dms-greeter" else "tuigreet")
        );
        message = "Arch login components require native packages and system units; Nix overrides are unsupported.";
      }
    ];
    software.requirements = lib.genAttrs (
      [ manager ] ++ lib.optional greetd (if useDmsGreeter then "dms-greeter" else "tuigreet")
    ) (_: { });
    home.activation.selectNativeLoginManager =
      lib.hm.dag.entryAfter [ "installNativePackages" "linkGeneration" ]
        (
          import ../../../../assets/helpers/display-manager-activation.nix { inherit lib pkgs; } {
            owner = config.home.username;
            service = "${manager}.service";
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
