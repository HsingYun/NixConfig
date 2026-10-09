{ lib, ... }:
{
  software.requirements = {
    gnupg = { };
    pinentry = { };
  };
  programs.gpg.enable = lib.mkDefault true;
  services.gpg-agent.enable = lib.mkDefault true;
}
