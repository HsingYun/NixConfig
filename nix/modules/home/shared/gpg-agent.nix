{
  config,
  lib,
  pkgs,
  software,
  ...
}:
let
  usesNixPackage = software.pinentry.provider == "nix";
in

{
  software = {
    bindings = {
      gnupg = {
        enableOption = [
          "programs"
          "gpg"
          "enable"
        ];
        packageOption = [
          "programs"
          "gpg"
          "package"
        ];
      };
      pinentry = {
        enableOption = [
          "services"
          "gpg-agent"
          "enable"
        ];
        packageOption = [
          "services"
          "gpg-agent"
          "pinentry"
          "package"
        ];
      };
    };
    requirements = {
      gnupg.capabilities = [ "store-package" ];
      pinentry = { };
    };
  };
  programs = {
    gpg = {
      package = lib.mkDefault software.gnupg.package;
      enable = lib.mkDefault true;
    };
  };
  services.gpg-agent = {
    pinentry = {
      package = lib.mkDefault software.pinentry.package;
      program = lib.mkIf (!usesNixPackage) (
        lib.mkDefault (if pkgs.stdenv.hostPlatform.isDarwin then "pinentry-mac" else "pinentry")
      );
    };
    # Upstream owns the agent and config file. An external pinentry needs only
    # its resolved command; Nix packages keep upstream's package-based path.
    extraConfig = lib.mkIf (!usesNixPackage) (
      "pinentry-program ${software.pinentry.command config.services.gpg-agent.pinentry.program}"
    );
    enable = lib.mkDefault true;
  };
}
