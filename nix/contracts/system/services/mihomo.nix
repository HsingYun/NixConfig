{ lib, ... }:
{
  # Portable subset of the upstream NixOS interface. Native ports delegate the
  # executable to the selected package provider when package is null.
  options.services.mihomo = {
    enable = lib.mkEnableOption "Mihomo system service";
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
    };
    configFile = lib.mkOption { type = lib.types.path; };
    tunMode = lib.mkEnableOption "permissions required by Mihomo TUN mode";
  };
}
