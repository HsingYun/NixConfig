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
          "papers"
          "snapshot"
          "sushi"
          "seahorse"
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
      "org/gnome/desktop/app-folders" = lib.mkIf config.features.desktop.gnome.flatAppGrid {
        # An explicit empty user value also prevents Shell from creating its
        # default folders. Preserve folder contents and the app grid layout.
        folder-children = lib.mkDefault (lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string);
      };
      "org/gnome/shell" = {
        favorite-apps = lib.mkDefault (
          [ "org.gnome.TextEditor.desktop" ]
          ++ lib.optional config.features.desktop.fileManager.enable "org.gnome.Nautilus.desktop"
          ++ lib.optional config.programs.ghostty.enable "com.mitchellh.ghostty.desktop"
        );
      }
      // lib.optionalAttrs native {
        disable-user-extensions = false;
        enabled-extensions = builtins.attrValues extensions;
      };
      "org/gnome/shell/extensions/dash-to-dock" = lib.mapAttrs (_: lib.mkDefault) {
        dock-position = "BOTTOM";
        dock-fixed = true;
        autohide = false;
        intellihide = false;
        custom-theme-shrink = true;
        disable-overview-on-startup = true;
        show-show-apps-button = true;
        show-apps-at-top = true;
        show-apps-always-in-the-edge = true;
        extend-height = true;
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
