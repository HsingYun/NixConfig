# GPG, its agent and pinentry share one upstream interface adapter.
{
  config,
  lib,
  software,
  ...
}:
{
  imports = [
    (import ../../../software/consumer.nix {
      scope = "home";
      id = "home-gnupg";
      software = "gnupg";
      # Both upstream branches use the same build-time keyring derivation.
      demands = {
        immutable-keys = {
          when = config: !config.programs.gpg.mutableKeys && config.programs.gpg.publicKeys != [ ];
          capabilities = [ "store-package" ];
        };
        immutable-trust = {
          when =
            config:
            !config.programs.gpg.mutableTrust
            && builtins.any (key: key.trust != null) config.programs.gpg.publicKeys;
          capabilities = [ "store-package" ];
        };
      };
      installedScopes = [ "home" ];
      enableOptions = [
        [
          "programs"
          "gpg"
          "enable"
        ]
      ];
      packageOption = [
        "programs"
        "gpg"
        "package"
      ];
    })
    (import ../../../software/consumer.nix {
      scope = "home";
      id = "home-gpg-agent-runtime";
      software = "gnupg";
      enableOptions = [
        [
          "services"
          "gpg-agent"
          "enable"
        ]
      ];
      packageOption = [
        "programs"
        "gpg"
        "package"
      ];
      capabilities = [ "store-package" ];
    })
    (import ../../../software/consumer.nix {
      scope = "home";
      id = "home-pinentry";
      software = "pinentry";
      enableOptions = [
        [
          "services"
          "gpg-agent"
          "enable"
        ]
      ];
      packageOption = [
        "services"
        "gpg-agent"
        "pinentry"
        "package"
      ];
    })
  ];
  services.gpg-agent =
    lib.mkIf
      (config.services.gpg-agent.enable && software ? pinentry && software.pinentry.provider != "nix")
      {
        pinentry.program = lib.mkDefault software.pinentry.mainProgram;
        extraConfig = "pinentry-program ${software.pinentry.command config.services.gpg-agent.pinentry.program}";
      };
}
