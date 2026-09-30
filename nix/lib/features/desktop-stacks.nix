# A desktop and its default login manager form one selectable stack.
{
  gnome = {
    features = [ "gnome" ];
    loginManager = "gdm";
    command = null; # GDM discovers its session through the platform.
  };
  niri = {
    features = [
      "niri"
      "dms"
    ];
    loginManager = "greetd";
    command = "niri-session";
  };
}
