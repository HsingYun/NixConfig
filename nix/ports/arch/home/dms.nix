{
  config,
  lib,
  pkgs,
  hostSystem,
  ...
}:
let
  cfg = config.programs.dank-material-shell;
  json = pkgs.formats.json { };
  unit = config.lib.file.mkOutOfStoreSymlink "/usr/lib/systemd/user/dms.service";
in
{
  # The upstream HM module always installs its Nix runtime. This adapter only
  # manages data and links Arch's service, keeping the native runtime intact.
  imports = [ ../../../contracts/home/dms.nix ];
  config = lib.mkMerge [
    {
      programs.dank-material-shell.systemd.enable = lib.mkDefault true;
    }
    (lib.mkIf cfg.enable {
      systemd.user.startServices = lib.mkIf cfg.systemd.enable (lib.mkDefault true);
      assertions = [
        {
          assertion = !cfg.systemd.enable || hostSystem.programs.niri.enable;
          message = "Arch DMS user service requires the Niri system session.";
        }
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
