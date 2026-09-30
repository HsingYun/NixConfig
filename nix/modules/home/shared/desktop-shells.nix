{ contracts }:
{
  config,
  osConfig,
  lib,
  ...
}:
let
  shells = lib.filterAttrs (
    name: _: builtins.elem "system.${name}" contracts && builtins.elem "home.${name}" contracts
  ) (import ../../../lib/features/desktop-shells.nix);
  running =
    shell:
    let
      system = osConfig.programs.${shell.systemProgram};
      home = config.programs.${shell.homeProgram};
    in
    (system.enable && system.systemd.enable) || (home.enable && home.systemd.enable);
in
{
  assertions = [
    {
      assertion = builtins.length (lib.filter running (builtins.attrValues shells)) <= 1;
      message = "System and Home Manager must not autostart different desktop shells in the same session. Select features.desktop.niri.shell and keep the other service disabled.";
    }
  ];
}
