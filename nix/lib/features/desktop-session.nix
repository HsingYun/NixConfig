# Shared desktop policy; platform adapters own package paths, units and PAM.
{ selected, enabled }:
let
  desktop =
    if selected.desktop != null then
      selected.desktop
    else if enabled.dms then
      "niri"
    else
      null;
  inherit (selected) loginManager;
in
{
  inherit desktop loginManager;
  greeter =
    if loginManager != "greetd" then
      null
    else if enabled.dms && desktop == "niri" then
      "dms-greeter"
    else
      "tuigreet";
  command =
    { gnomeSession }:
    if desktop == "gnome" then
      "env XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=GNOME ${gnomeSession} --session=gnome"
    else
      "niri-session";
}
