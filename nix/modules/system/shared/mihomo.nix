{ config, lib, ... }:
{
  imports = [
    (import ../../software/consumer.nix {
      scope = "system";
      id = "system-mihomo";
      software = "mihomo";
      packageOption = [
        "services"
        "mihomo"
        "package"
      ];
      enableOptions = [
        [
          "services"
          "mihomo"
          "enable"
        ]
      ];
    })
  ];
  software.requirements.mihomo = lib.mkIf config.services.mihomo.enable { scopes = [ "system" ]; };
}
