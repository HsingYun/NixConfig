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
    requirements = {
      gnupg.capabilities = [ "store-package" ];
      pinentry = { };
    };
  };
  programs = {
    gpg = {
      enable = lib.mkDefault true;
    };
  };
  services.gpg-agent = {
    pinentry = {
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
