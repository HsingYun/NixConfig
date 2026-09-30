{ desktopSession, enabled }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (desktopSession) desktop loginManager;
  useDmsGreeter = desktopSession.greeter == "dms-greeter";
in
{
  services = {
    displayManager = {
      # Beat individual desktop modules' mkDefault without forcing host options.
      defaultSession = lib.mkIf (desktop != null) (lib.mkOverride 900 desktop);
      gdm.enable = lib.mkIf enabled.gnome (lib.mkDefault (loginManager == "gdm"));
      dms-greeter = {
        package = lib.mkIf useDmsGreeter (
          lib.mkDefault (
            import ../../../assets/helpers/common/greeter-session.nix { inherit lib pkgs; } {
              command = "${pkgs.dms-greeter}/bin/dms-greeter";
              cacheDir = "/var/lib/dms-greeter";
              inherit desktop;
            }
          )
        );
        enable = lib.mkIf enabled.dms (lib.mkDefault useDmsGreeter);
        compositor.name = lib.mkIf useDmsGreeter (lib.mkDefault "niri");
      };
    };
    greetd = lib.mkIf ((enabled.niri || enabled.gnome) && !useDmsGreeter) {
      enable = lib.mkDefault (loginManager == "greetd");
      settings.default_session = lib.mkIf (loginManager == "greetd") {
        command = "${lib.getExe pkgs.tuigreet} --time --cmd ${lib.escapeShellArg desktopSession.command}";
        user = "greeter";
      };
    };
  };
  assertions = lib.optionals (enabled.gnome || enabled.niri || enabled.dms) [
    {
      assertion = !(config.services.displayManager.gdm.enable && config.services.greetd.enable);
      message = "GDM and greetd (including DMS greeter) cannot both own the login screen. Select preferences.desktop and remove conflicting system overrides.";
    }
  ];
}
