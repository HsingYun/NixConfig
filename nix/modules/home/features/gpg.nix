{ lib, ... }:

{
  imports = [ ../shared/gpg-agent.nix ];
  services.gpg-agent.enableZshIntegration = lib.mkDefault true;
}
