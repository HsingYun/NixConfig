# Shared desktop policy; platform adapters own package paths, units and PAM.
{
  selected,
  enabled,
  sessions ? builtins.mapAttrs (_: stack: builtins.removeAttrs stack [ "features" ]) (
    import ./desktop-stacks.nix
  ),
}:
let
  inherit (selected) desktop;
  # Select a whole desktop stack. The login manager follows its desktop;
  # platform adapters retain ownership of upstream/native service settings.
  loginManager = if desktop == null then "none" else sessions.${desktop}.loginManager;

in
{
  inherit desktop loginManager;
  greeter =
    if loginManager != "greetd" then
      null
    else if enabled.dms then
      "dms-greeter"
    else
      "tuigreet";
  # GDM discovers GNOME through its upstream session definition.
  command = if desktop == null then null else sessions.${desktop}.command;
}
