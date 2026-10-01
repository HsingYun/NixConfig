{ config, lib, ... }:
let
  cfg = config.services.mihomo;
in
{
  imports = [
    ../../../contracts/system/services/mihomo.nix
    ../../../modules/system/shared/mihomo.nix
  ];
  config = lib.mkIf cfg.enable {
    # launchd owns the privileged daemon; Homebrew only supplies the executable.
    # Mihomo creates its state directory itself, under launchd's restrictive umask.
    launchd.daemons.mihomo.serviceConfig = {
      ProgramArguments = [
        (config.software.resolved.mihomo.command "mihomo")
        "-d"
        "/private/var/lib/mihomo"
        "-f"
        (toString cfg.configFile)
      ];
      UserName = "root";
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 10;
      Umask = 63;
      StandardOutPath = "/private/var/log/mihomo.log";
      StandardErrorPath = "/private/var/log/mihomo.log";
    };
  };
}
