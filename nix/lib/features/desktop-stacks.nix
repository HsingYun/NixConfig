# A desktop and its default login manager form one selectable stack.
{
  gnome = {
    features = [ "gnome" ];
    loginManager = "gdm";
    command = "gnome-session";
    activation = [
      "services"
      "desktopManager"
      "gnome"
      "enable"
    ];
  };
  niri = {
    features = [ "niri" ] ++ builtins.attrNames (import ./desktop-shells.nix);
    loginManager = "greetd";
    command = "niri-session";
    activation = [
      "programs"
      "niri"
      "enable"
    ];
  };
}
