{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.desktop.keyring;
  keyring = config.software.resolved.gnome-keyring;
  usesNixPackage = keyring.provider == "nix";
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isLinux;
        message = "features.desktop.keyring is only supported on Linux.";
      }
    ];

    software.requirements.gnome-keyring = { };
    systemd.user.startServices = lib.mkDefault true;

    # Let the official Home Manager module maintain Nix runtime integration.
    services.gnome-keyring = lib.mkIf usesNixPackage {
      enable = lib.mkDefault true;
      components = [
        "pkcs11"
        "secrets"
      ];
    };
  };
}
