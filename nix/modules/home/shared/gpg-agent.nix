{ lib, software, ... }:

{
  software.bindings = {
    gnupg.enableOption = [
      "programs"
      "gpg"
      "enable"
    ];
    pinentry.enableOption = [
      "services"
      "gpg-agent"
      "enable"
    ];
    gnupg.packageOption = [
      "programs"
      "gpg"
      "package"
    ];
    pinentry.packageOption = [
      "services"
      "gpg-agent"
      "pinentry"
      "package"
    ];
  };
  software.requirements = {
    gnupg.capabilities = [ "store-package" ];
    pinentry.capabilities = [ "store-package" ];
  };
  programs.gpg.package = lib.mkDefault software.gnupg.package;
  programs.gpg.enable = lib.mkDefault true;
  services.gpg-agent = {
    pinentry.package = lib.mkDefault software.pinentry.package;
    enable = lib.mkDefault true;
  };
}
