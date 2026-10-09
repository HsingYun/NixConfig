{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.desktop.keyring.enable {
    software.requirements.gnome-keyring.scopes = [ "system" ];
    assertions = [
      {
        assertion = toString config.software.resolved.gnome-keyring.package == toString pkgs.gnome-keyring;
        message = "NixOS keyring must use pkgs.gnome-keyring consistently for PAM, DBus and its capability wrapper. Customize it through a system nixpkgs overlay, not a Home Manager package override.";
      }
    ];
  };
}
