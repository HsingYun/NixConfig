{ lib, desktopSession, ... }:
{
  services.displayManager = {
    defaultSession = lib.mkIf (desktopSession.desktop != null) (
      lib.mkOverride 900 desktopSession.desktop
    );
    gdm.enable = lib.mkDefault (desktopSession.loginManager == "gdm");
    dms-greeter.enable = lib.mkDefault (desktopSession.greeter == "dms-greeter");
  };
  services.greetd.enable = lib.mkDefault (desktopSession.loginManager == "greetd");
}
