{ lib, ... }:
{
  options = {
    programs.gpg = {
      enable = lib.mkEnableOption "GnuPG";
      package = lib.mkOption { type = lib.types.package; };
    };
    services.gpg-agent = {
      enable = lib.mkEnableOption "GPG agent";
      enableSshSupport = lib.mkEnableOption "GPG SSH agent";
      pinentry.package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
      };
    };
  };
}
