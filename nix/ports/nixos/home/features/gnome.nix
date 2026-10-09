{ software, ... }:
{
  software.requirements = builtins.listToAttrs (
    map
      (name: {
        inherit name;
        value.capabilities = [ "store-package" ];
      })
      [
        "gnome-user-themes"
        "gnome-dash-to-dock"
        "gnome-desktop-icons"
      ]
  );
  programs.gnome-shell.extensions = map (package: { inherit package; }) [
    software.gnome-user-themes.package
    software.gnome-dash-to-dock.package
    software.gnome-desktop-icons.package
  ];
}
