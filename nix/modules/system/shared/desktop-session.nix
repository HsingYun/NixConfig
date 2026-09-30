{ config, lib, ... }:
let
  stacks = import ../../../lib/features/desktop-stacks.nix;
  session = lib.attrByPath [ "services" "displayManager" "defaultSession" ] null config;
  shells = import ../../../lib/features/desktop-shells.nix;
  greeters = lib.filter (
    shell: lib.attrByPath [ "services" "displayManager" shell.greeter "enable" ] false config
  ) (builtins.attrValues shells);
  gdm = lib.attrByPath [ "services" "displayManager" "gdm" "enable" ] false config;
  greetd = lib.attrByPath [ "services" "greetd" "enable" ] false config;
in
{
  assertions = [
    {
      assertion = builtins.length greeters <= 1;
      message = "Only one graphical greeter may own greetd. Select features.desktop.niri.shell or explicitly disable the other greeter.";
    }

    {
      assertion = !(gdm && greetd);
      message = "GDM and greetd cannot both own the login screen. Select the preferred desktop or override one manager.";
    }
  ]
  ++ lib.mapAttrsToList (name: stack: {
    assertion = !(gdm || greetd) || session != name || lib.attrByPath stack.activation false config;
    message = "Default desktop '${name}' is disabled in the final system configuration. Enable its session or select another default desktop.";
  }) stacks;
}
