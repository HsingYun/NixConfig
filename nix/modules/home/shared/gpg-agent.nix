{ lib, pkgs, ... }:

{
  programs.gpg.enable = lib.mkDefault true;
  services.gpg-agent = {
    enable = lib.mkDefault true;
    pinentry.package = lib.mkDefault (
      if pkgs.stdenv.hostPlatform.isDarwin then pkgs.pinentry_mac else pkgs.pinentry-qt
    );
  };
}
