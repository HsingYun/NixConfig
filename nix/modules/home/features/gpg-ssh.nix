{ lib, ... }:

{
  imports = [ ../shared/gpg-agent.nix ];
  services.gpg-agent.enableSshSupport = lib.mkDefault true;
}
