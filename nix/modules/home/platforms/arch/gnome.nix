{ config, lib, ... }:
{
  software.requirements = lib.genAttrs [
    "gdm"
    "gnome-color-manager"
    "gnome-control-center"
    "gnome-disk-utility"
    "gnome-font-viewer"
    "gnome-keyring"
    "gnome-logs"
    "gnome-menus"
    "gnome-session"
    "gnome-settings-daemon"
    "gnome-shell"
    "gnome-system-monitor"
    "loupe"
    "malcontent"
    "papers"
    "sushi"
    "seahorse"
    "xdg-desktop-portal-gnome"
  ] (_: { });
  assertions = [
    {
      assertion = lib.all (name: config.software.resolved.${name}.provider == "pacman") [
        "gnome-shell"
        "gnome-session"
        "gnome-settings-daemon"
        "xdg-desktop-portal-gnome"
        "gnome-user-themes"
        "gnome-dash-to-dock"
        "gnome-desktop-icons"
      ];
      message = "Arch owns GNOME and its ABI-compatible extensions; select pacman packages.";
    }
  ];
  dconf.settings."org/gnome/shell" = {
    disable-user-extensions = false;
    enabled-extensions = [
      "user-theme@gnome-shell-extensions.gcampax.github.com"
      "dash-to-dock@micxgx.gmail.com"
      "ding@rastersoft.com"
    ];
  };
}
