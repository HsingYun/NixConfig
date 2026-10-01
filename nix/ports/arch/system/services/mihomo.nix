{ config, lib, ... }:
let
  cfg = config.services.mihomo;
  command = config.software.resolved.mihomo.command "mihomo";
in
{
  imports = [
    ../../../../contracts/system/services/mihomo.nix
    ../../../../modules/system/shared/mihomo.nix
  ];
  config = lib.mkIf cfg.enable {
    native.systemd.units = [ "mihomo.service" ];
    native.systemd.definitions."mihomo.service" = {
      Unit = {
        Description = "Mihomo daemon";
        Wants = "network-online.target";
        After = "network-online.target";
      };
      Install.WantedBy = "multi-user.target";
      Service = {
        ExecStart = "${command} -d /var/lib/mihomo -f \${CREDENTIALS_DIRECTORY}/config.yaml";
        LoadCredential = "config.yaml:${cfg.configFile}";
        DynamicUser = true;
        StateDirectory = "mihomo";
        UMask = "0077";
        Restart = "on-failure";
        RestartSec = 5;
        AmbientCapabilities = if cfg.tunMode then "CAP_NET_ADMIN" else "";
        CapabilityBoundingSet = if cfg.tunMode then "CAP_NET_ADMIN" else "";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = !cfg.tunMode;
        RestrictAddressFamilies = "AF_INET AF_INET6" + lib.optionalString cfg.tunMode " AF_NETLINK";
      };
    };
  };
}
