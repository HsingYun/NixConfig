{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.dank-material-shell;
  json = pkgs.formats.json { };
  settingsOption =
    description:
    lib.mkOption {
      type = json.type;
      default = { };
      inherit description;
    };
  unit = config.lib.file.mkOutOfStoreSymlink "/usr/lib/systemd/user/dms.service";
in
{
  # The upstream HM module always installs its Nix runtime. This adapter only
  # manages data and links Arch's service, keeping the native runtime intact.
  options.programs.dank-material-shell = {
    enable = lib.mkEnableOption "Arch DankMaterialShell configuration";
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
    };
    settings = settingsOption "Declarative DMS settings.";
    session = settingsOption "Declarative DMS session state.";
    clipboardSettings = settingsOption "Declarative DMS clipboard settings.";
    enableCalendarEvents = lib.mkEnableOption "DMS calendar dependencies";
    systemd.enable = lib.mkEnableOption "Arch DMS user service";
  };
  config = lib.mkMerge [
    {
      programs.dank-material-shell.systemd.enable = lib.mkDefault true;
      software.requirements.dms = { };
    }
    (lib.mkIf cfg.enable {
      systemd.user.startServices = lib.mkIf cfg.systemd.enable (lib.mkDefault true);
      assertions = [
        {
          assertion = cfg.package == null && config.software.packageManager.type == "pacman";
          message = "Arch DMS requires pacman and its system-provided package.";
        }
      ];
      software.requirements = lib.genAttrs (
        [
          "matugen"
          "cava"
        ]
        ++ lib.optional cfg.enableCalendarEvents "khal"
      ) (_: { });
      xdg = {
        stateFile."DankMaterialShell/session.json" = lib.mkIf (cfg.session != { }) {
          source = json.generate "dms-session.json" cfg.session;
        };
        configFile = {
          "DankMaterialShell/settings.json" = lib.mkIf (cfg.settings != { }) {
            source = json.generate "dms-settings.json" cfg.settings;
          };
          "DankMaterialShell/clsettings.json" = lib.mkIf (cfg.clipboardSettings != { }) {
            source = json.generate "dms-clipboard.json" cfg.clipboardSettings;
          };
          "systemd/user/dms.service" = lib.mkIf cfg.systemd.enable { source = unit; };
          "systemd/user/niri.service.wants/dms.service" = lib.mkIf cfg.systemd.enable { source = unit; };
          "systemd/user/dms.service.d/nixconfig.conf" = lib.mkIf cfg.systemd.enable {
            text = ''
              [Unit]
              PartOf=niri.service
              ConditionEnvironment=XDG_CURRENT_DESKTOP=niri
            '';
          };
        };
      };
    })
  ];
}
