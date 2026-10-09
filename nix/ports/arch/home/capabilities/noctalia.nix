{
  config,
  lib,
  osConfig,
  software,
  ...
}:
let
  cfg = osConfig.programs.noctalia;
  home = config.programs.noctalia;
  file = import ../../../../assets/helpers/common/managed-home-file.nix { inherit lib; } {
    home = config;
    name = "${config.xdg.configHome}/noctalia/config.toml";
  };
  # An explicit HM service owns the user's unit, as it does over a system-wide
  # user unit on NixOS. The system port only supplies the otherwise missing unit.
  homeService = home.enable && home.systemd.enable;
  systemService = cfg.enable && cfg.systemd.enable && !homeService;
in
{
  imports = [ ../../../../modules/home/software/adapters/noctalia.nix ];
  # Reuse Home Manager's nullable package option and configuration generator.
  # Arch's package does not ship a user unit, so implement the system service
  # contract through HM's systemd interface using the selected executable.
  config = lib.mkMerge [
    (lib.mkIf (home.enable && home.package == null && home.checkConfig && file.enable) {
      home.activation.validateArchNoctalia =
        lib.hm.dag.entryBetween [ "linkGeneration" ] [ "installNativePackages" ]
          ''
            run ${lib.escapeShellArg (software.noctalia.command "noctalia")} config validate ${lib.escapeShellArg (toString file.source)}
          '';
    })
    (lib.mkIf systemService {
      systemd.user = {
        startServices = lib.mkDefault true;
        services.noctalia = {
          Unit = {
            Description = "Noctalia Wayland desktop shell";
            PartOf = [ cfg.systemd.target ];
            After = [ cfg.systemd.target ];
            ConditionEnvironment = lib.mkIf (cfg.systemd.target == "niri.service") "XDG_CURRENT_DESKTOP=niri";
          };
          Service = {
            ExecStart = software.noctalia.command "noctalia";
            Restart = "on-failure";
          };
          Install.WantedBy = [ cfg.systemd.target ];
        };
      };
    })
  ];
}
