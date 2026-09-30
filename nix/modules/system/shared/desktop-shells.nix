{ desktopDefaults, contracts }:
{ config, lib, ... }:
let
  shells = lib.filterAttrs (name: _: builtins.elem "system.${name}" contracts) (
    import ../../../lib/features/desktop-shells.nix
  );
  running =
    shell:
    let
      cfg = config.programs.${shell.systemProgram};
    in
    cfg.enable && cfg.systemd.enable;
in
{
  config = lib.mkMerge (
    [
      {
        assertions = [
          {
            assertion = builtins.length (lib.filter running (builtins.attrValues shells)) <= 1;
            message = "Only one desktop shell may autostart. Select features.desktop.niri.shell or disable the other shell's systemd service.";
          }
        ];
      }
    ]
    ++ lib.mapAttrsToList (name: shell: {
      programs.${shell.systemProgram}.systemd.enable = lib.mkIf (desktopDefaults.shell != null) (
        lib.mkDefault (desktopDefaults.shell == name)
      );
    }) shells
  );
}
