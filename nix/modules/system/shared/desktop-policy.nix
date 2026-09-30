# One owner for feature-derived defaults, shared by every desktop port.
# Capability implementations may add positive service dependencies; an
# unselected optional service keeps its upstream/schema default rather than
# receiving a competing negative definition here.
{ desktopDefaults, contracts }:
{ lib, ... }:
{
  imports = [
    ./desktop-session.nix
    (import ./desktop-shells.nix { inherit desktopDefaults contracts; })
  ]
  ++ lib.optional (builtins.elem "system.noctalia-greeter" contracts) ./noctalia-greeter.nix;
  config = lib.mkMerge [
    {
      services.displayManager.defaultSession = lib.mkIf (desktopDefaults.desktop != null) (
        lib.mkOverride 900 desktopDefaults.desktop
      );
    }
    (lib.optionalAttrs (builtins.elem "system.gnome" contracts) {
      services.displayManager.gdm.enable = lib.mkIf (desktopDefaults.loginManager == "gdm") (
        lib.mkDefault true
      );
    })
    (lib.optionalAttrs (builtins.elem "system.niri" contracts) {
      services.greetd.enable = lib.mkIf (desktopDefaults.loginManager == "greetd") (lib.mkDefault true);
    })
    (lib.mkMerge (
      lib.mapAttrsToList (
        _: shell:
        lib.optionalAttrs (builtins.elem shell.greeterContract contracts) {
          services.displayManager.${shell.greeter}.enable = lib.mkIf (
            desktopDefaults.greeter == shell.greeter
          ) (lib.mkDefault true);
        }
      ) (import ../../../lib/features/desktop-shells.nix)
    ))
  ];
}
