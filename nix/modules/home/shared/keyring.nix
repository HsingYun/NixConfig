{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.desktop.keyring;
  platform = config.software.platform;
  isNixos = builtins.elem platform [
    "nixos"
    "nixos-wsl"
  ];
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
      {
        assertion = !isNixos || toString keyring.package == toString pkgs.gnome-keyring;
        message = "NixOS keyring must use pkgs.gnome-keyring consistently for PAM, DBus and its capability wrapper. Customize it through a system nixpkgs overlay, not a Home Manager package override.";
      }
    ];

    software.requirements.gnome-keyring.scopes = [ (if isNixos then "system" else "home") ];
    systemd.user.startServices = lib.mkDefault true;

    # Let the official Home Manager module maintain Nix runtime integration.
    services.gnome-keyring = lib.mkIf usesNixPackage {
      enable = lib.mkDefault true;
      package = keyring.package;
      components = [
        "pkcs11"
        "secrets"
      ];
    };
  };
}
