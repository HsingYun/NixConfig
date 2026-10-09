{ config, lib, ... }:
{
  config =
    lib.mkIf
      (
        config.features.desktop.niri.enable
        && config.wayland.windowManager.niri.enable
        && config.programs.ghostty.enable
      )
      {
        programs.ghostty.settings = {
          # The tabs style keeps a top bar even without client-side decorations.
          gtk-titlebar-style = lib.mkDefault "native";
          # Niri supplies the frame; Ghostty falls back to its titlebar on GNOME.
          window-decoration = lib.mkDefault "server";
        };
      };
}
