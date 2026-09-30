{
  config,
  lib,
  pkgs,
  ...
}:
let
  stacks = import ../../../lib/features/desktop-stacks.nix;
  session = config.services.displayManager.defaultSession;
  useNoctaliaGreeter = config.services.displayManager.noctalia-greeter.enable;
  useDmsGreeter = config.services.displayManager.dms-greeter.enable;
  command = if session == null then null else stacks.${session}.command or null;
in
{
  services = {
    displayManager.dms-greeter = {
      package = lib.mkIf (useDmsGreeter && session != null) (
        lib.mkDefault (
          import ../../../assets/helpers/common/greeter-session.nix { inherit lib pkgs; } {
            command = "${pkgs.dms-greeter}/bin/dms-greeter";
            cacheDir = "/var/lib/dms-greeter";
            desktop = session;
          }
        )
      );
    };
    greetd = {
      settings.default_session =
        lib.mkIf (config.services.greetd.enable && !useDmsGreeter && !useNoctaliaGreeter && command != null)
          {
            command = lib.mkDefault "${lib.getExe pkgs.tuigreet} --time --cmd ${lib.escapeShellArg command}";
            user = lib.mkDefault "greeter";
          };
    };
  };
}
