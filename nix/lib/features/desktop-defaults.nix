# Feature selection supplies defaults; runtime behavior uses final module options.
{
  selected,
  sessions ? builtins.mapAttrs (_: stack: builtins.removeAttrs stack [ "features" ]) (
    import ./desktop-stacks.nix
  ),
}:
let
  inherit (selected) desktop;
  shells = import ./desktop-shells.nix;
  shell = selected.desktopShell;
  # Select a whole desktop stack. The login manager follows its desktop;
  # platform adapters retain ownership of upstream/native service settings.
  loginManager = if desktop == null then "none" else sessions.${desktop}.loginManager;

in
{
  inherit desktop loginManager;
  inherit shell;
  greeter =
    if loginManager != "greetd" then
      null
    else if shell != null then
      shells.${shell}.greeter
    else
      "tuigreet";
}
