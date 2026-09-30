{ lib, ... }: {
  imports = [ ../shared/desktop.nix ];
  services.desktopManager.gnome.enable = lib.mkDefault true;
}
