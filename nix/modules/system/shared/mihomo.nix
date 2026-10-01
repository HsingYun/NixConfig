{ config, lib, ... }:
{
  imports = [
    (import ../../software/consumer.nix {
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
      requestWhenEnabled = true;
    })
  ];
  software.requirements.mihomo = lib.mkIf config.services.mihomo.enable { scopes = [ "system" ]; };
}
