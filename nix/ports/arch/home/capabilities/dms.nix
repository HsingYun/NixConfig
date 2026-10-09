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
in
{
  # The upstream HM module always installs its Nix runtime. This adapter only
  # manages data and links Arch's service, keeping the native runtime intact.
  imports = [
    ../../../../modules/home/software/adapters/dms.nix
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
      assertions = [
        {
          assertion = osConfig.programs.niri.enable;
          message = "Arch DMS user service requires the Niri system session.";
        }
      ];
      native.systemd.user.units."dms.service" = {
        wantedBy = [ "niri.service" ];
        dropIns."nixconfig.conf".Unit = {
          PartOf = "niri.service";
          ConditionEnvironment = "XDG_CURRENT_DESKTOP=niri";
        };
      };
    })
  ];
}
