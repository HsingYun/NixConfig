{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  cfg = config.programs.dank-material-shell;
  json = pkgs.formats.json { };
  runService =
    (osConfig.programs.dms-shell.enable && osConfig.programs.dms-shell.systemd.enable)
    || (cfg.enable && cfg.systemd.enable);
  unit = config.lib.file.mkOutOfStoreSymlink "/usr/lib/systemd/user/dms.service";
in
{
  # The upstream HM module always installs its Nix runtime. This adapter only
  # manages data and links Arch's service, keeping the native runtime intact.
  imports = [
    ../../../../modules/home/software/dms-consumer.nix
    ../../../../contracts/home/dms.nix
  ];
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.package == null && config.software.resolved.dms.provider == "pacman";
          message = "Arch DMS requires pacman and its system-provided package.";
        }
      ];
      software.requirements = lib.genAttrs (
        [
          "dms"
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
        };
      };
    })
    (lib.mkIf runService {
      systemd.user.startServices = lib.mkDefault true;
      assertions = [
        {
          assertion = osConfig.programs.niri.enable;
          message = "Arch DMS user service requires the Niri system session.";
        }
      ];
      xdg.configFile = {
        "systemd/user/dms.service" = {
          source = unit;
        };
        "systemd/user/niri.service.wants/dms.service" = {
          source = unit;
        };
        "systemd/user/dms.service.d/nixconfig.conf" = {
          text = ''
            [Unit]
            PartOf=niri.service
            ConditionEnvironment=XDG_CURRENT_DESKTOP=niri
          '';
        };
      };
    })
  ];
}
