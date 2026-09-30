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
in
{
  imports = [ ../../../../modules/home/software/noctalia-consumer.nix ];
  # Reuse Home Manager's nullable package option and configuration generator.
  # Arch's package does not ship a user unit, so implement the system service
  # contract through HM's systemd interface using the selected executable.
  config = lib.mkMerge [
    (lib.mkIf
      (
        home.enable
        && home.package == null
        && home.checkConfig
        && config.xdg.configFile ? "noctalia/config.toml"
      )
      {
        home.activation.validateArchNoctalia =
          lib.hm.dag.entryBetween [ "linkGeneration" ] [ "installNativePackages" ]
            ''
              run ${lib.escapeShellArg (software.noctalia.command "noctalia")} config validate ${
                lib.escapeShellArg (toString config.xdg.configFile."noctalia/config.toml".source)
              }
            '';
      }
    )
    (lib.mkIf (cfg.enable && cfg.systemd.enable) {
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
