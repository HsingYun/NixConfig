# Native hosts default to configuration-only integration. Opt-in upstream
# subfeatures contribute demand before selection; HM still implements them.
# NixOS does not import this adapter and keeps every upstream default.
{ lib, ... }:
{
  imports = [
    (import ../../../../modules/software/consumer.nix {
      scope = "home";
      id = "home-ghostty-integrations";
      software = "ghostty";
      enableOptions = [
        [
          "programs"
          "ghostty"
          "enable"
        ]
      ];
      packageOption = [
        "programs"
        "ghostty"
        "package"
      ];
      demands = {
        systemd = {
          when = config: config.programs.ghostty.systemd.enable;
          capabilities = [
            "store-package"
            "systemd-service"
          ];
        };
        vim-syntax = {
          when = config: config.programs.ghostty.installVimSyntax;
          capabilities = [ "store-package" ];
        };
        bat-syntax = {
          when = config: config.programs.ghostty.installBatSyntax;
          capabilities = [ "store-package" ];
        };
      };
    })
  ];
  # These are input defaults, not consequences of provider selection. In
  # particular HM's package-dependent bat default cannot feed back into demand.
  programs.ghostty = {
    systemd.enable = lib.mkDefault false;
    installBatSyntax = lib.mkDefault false;
  };
}
