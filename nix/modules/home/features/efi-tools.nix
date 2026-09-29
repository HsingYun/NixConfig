{ config, ... }:
{
  # Keep firmware maintenance tools in the NixOS system environment.
  software.requirements.efibootmgr.scopes = [
    (if config.software.platform == "nixos" then "system" else "home")
  ];
}
