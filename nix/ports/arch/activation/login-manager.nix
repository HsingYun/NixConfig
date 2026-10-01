{
  config,
  lib,
  pkgs,
  user,
  ...
}:
let
  desktop = config.services.displayManager.defaultSession;
  stacks = import ../../../lib/features/desktop-stacks.nix;
  sessionCommand = if desktop == null then null else stacks.${desktop}.command or null;
  manager =
    if config.services.displayManager.gdm.enable then
      "gdm"
    else if config.services.greetd.enable then
      "greetd"
    else
      "none";
  greetd = manager == "greetd";
  useNoctaliaGreeter = config.services.displayManager.noctalia-greeter.enable;
  noctaliaGreeter = config.services.displayManager.noctalia-greeter;
  useDmsGreeter = config.services.displayManager.dms-greeter.enable;
  greeter =
    if useDmsGreeter then
      "dms-greeter"
    else if useNoctaliaGreeter then
      "noctalia-greeter"
    else
      "tuigreet";
  dmsGreeter =
    if desktop == null then
      null
    else
      import ../../../assets/helpers/common/greeter-session.nix { inherit lib pkgs; } {
        command = "/usr/bin/dms-greeter";
        cacheDir = "/var/cache/dms-greeter";
        inherit desktop;
      };
  greeterCommand =
    if useDmsGreeter then
      "${
        if dmsGreeter == null then "/usr" else dmsGreeter
      }/bin/dms-greeter --command niri --cache-dir /var/cache/dms-greeter -C /etc/greetd/nixconfig-niri.kdl"
    else if useNoctaliaGreeter then
      (lib.optionalString (noctaliaGreeter.settings != { })
        "/usr/bin/bwrap --die-with-parent --bind / / --dev-bind /dev /dev --ro-bind /etc/greetd/nixconfig-noctalia.toml /var/lib/noctalia-greeter/greeter.toml -- "
      )
      + "/usr/bin/noctalia-greeter-session ${lib.escapeShellArgs noctaliaGreeter.extraArgs}"
    else if sessionCommand != null then
      "/usr/bin/tuigreet --time --cmd ${lib.escapeShellArg sessionCommand}"
    else
      null;
  greetdConfig =
    (pkgs.formats.toml { }).generate "greetd-nixconfig.toml"
      config.services.greetd.settings;
  # The greeter command binds its declared config inside its own process
  # namespace. greetd and the desktop it launches retain the host filesystem.
  greetdUnit = (pkgs.formats.systemd { }).generate "greetd-nixconfig.conf" {
    Service.ExecStart = [
      ""
      "/usr/bin/greetd --config /etc/greetd/nixconfig.toml"
    ];
  };
  niriConfig = pkgs.writeText "greeter-niri.kdl" ''
    hotkey-overlay { skip-at-startup; }
    environment { DMS_RUN_GREETER "1"; }
    gestures { hot-corners { off; }; }
    layout { background-color "#000000"; }
  '';
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
    ++ lib.optional (useNoctaliaGreeter && noctaliaGreeter.settings != { }) {
      source = toString (
        (pkgs.formats.toml { }).generate "noctalia-greeter.toml" noctaliaGreeter.settings
      );
      destination = "/etc/greetd/nixconfig-noctalia.toml";
    }
    ++ lib.optional useDmsGreeter {
      source = toString niriConfig;
      destination = "/etc/greetd/nixconfig-niri.kdl";
    }
  );
in
{
  config = {
    native.resources.loginManager = {
      desired = { inherit manager files; };
      check = lib.mkIf (manager != "none") ''
        test "$(${pkgs.coreutils}/bin/basename "$(${pkgs.coreutils}/bin/readlink -f /etc/systemd/system/display-manager.service)")" = ${manager}.service
        /usr/bin/systemctl is-enabled ${manager}.service
        test "$(/usr/bin/systemctl get-default)" = graphical.target
        ${lib.concatMapStringsSep "\n" (
          file:
          "${pkgs.diffutils}/bin/cmp ${lib.escapeShellArg file.source} ${lib.escapeShellArg file.destination}"
        ) files}
      '';
    };
    assertions = [
      {
        assertion = !greetd || (config.services.greetd.settings.default_session.command or "") != "";
        message = "Arch greetd requires a known default desktop or an explicit services.greetd.settings.default_session.command.";
      }
    ];
    services.greetd.settings = lib.mkIf greetd {
      terminal.vt = lib.mkDefault 1;
      default_session = {
        command = lib.mkIf (greeterCommand != null) (lib.mkDefault greeterCommand);
        user = lib.mkDefault "greeter";
      };
    };
    native.requiredPackages = lib.optional (manager != "none") manager ++ lib.optional greetd greeter;
    native.activation.checkNativeGreeter =
      lib.mkIf (greetd && useNoctaliaGreeter && noctaliaGreeter.settings != { })
        (
          lib.hm.dag.entryBetween [ "linkGeneration" ] [ "installNativePackages" ] ''
            # Verify the actual greeter account can create its config namespace
            # before changing the login manager. Never relax host namespace policy.
            run /usr/bin/sudo -u ${lib.escapeShellArg config.services.greetd.settings.default_session.user} \
              /usr/bin/bwrap --bind / / -- /usr/bin/true || {
              echo "Noctalia Greeter requires user namespaces for its declarative configuration." >&2
              exit 1
            }
          ''
        );
    native.activation.selectNativeLoginManager =
      lib.hm.dag.entryAfter [ "installNativePackages" "linkGeneration" ]
        (
          import ../../../assets/helpers/arch/display-manager-activation.nix { inherit lib pkgs; } {
            owner = user.username;
            service = if manager == "none" then null else "${manager}.service";
            inherit files;
          }
        );
  };
}
