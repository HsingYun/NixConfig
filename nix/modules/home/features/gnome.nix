{
  config,
  lib,
  software,
  ...
}:
let
  native = config.software.platform == "arch";
  extensions = {
    gnome-user-themes = "user-theme@gnome-shell-extensions.gcampax.github.com";
    gnome-dash-to-dock = "dash-to-dock@micxgx.gmail.com";
    gnome-desktop-icons = "ding@rastersoft.com";
  };
in
{
  imports = [ ../shared/desktop.nix ];

  software.requirements =
    lib.genAttrs
      (
        [
          "mission-center"
          "gnome-text-editor"
          "snapshot"
          "gnome-user-themes"
          "gnome-dash-to-dock"
          "gnome-desktop-icons"
        ]
        # Explicit Arch package selection; pacman resolves their dependencies.
        ++ lib.optionals native [
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
          "gnome-text-editor"
          "loupe"
          "malcontent"
          "nautilus"
          "papers"
          "snapshot"
          "sushi"
          "xdg-desktop-portal-gnome"
        ]
      )
      (_: {
        capabilities = lib.optionals (!native) [ "store-package" ];
      });
  assertions = lib.optional native {
    assertion =
      config.software.packageManager.type == "pacman"
      && lib.all (name: config.software.resolved.${name}.provider == "pacman") [
        "gnome-shell"
        "gnome-session"
        "gnome-settings-daemon"
        "xdg-desktop-portal-gnome"
        "gnome-user-themes"
        "gnome-dash-to-dock"
        "gnome-desktop-icons"
      ];
    message = "Standalone GNOME features currently require pacman; Arch owns GNOME and its extensions.";
  };
  dconf.settings = lib.mkMerge [
    config.features.desktop.gnome.settings
    {
      "org/gnome/shell" = lib.mkIf native {
        disable-user-extensions = false;
        enabled-extensions = builtins.attrValues extensions;
      };
    }
  ];

  programs.gnome-shell = {
    enable = lib.mkDefault true;
    extensions = lib.optionals (!native) (
      map (package: { inherit package; }) ([
        software.gnome-user-themes.package
        software.gnome-dash-to-dock.package
        software.gnome-desktop-icons.package
      ])
    );
  };

  xdg.userDirs = {
    enable = lib.mkDefault true;
    createDirectories = lib.mkDefault true;
  };
}
