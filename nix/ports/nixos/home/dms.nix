{ lib, ... }:
{
  # NixOS owns the service; upstream Home Manager owns its configuration.
  programs.dank-material-shell.systemd.enable = lib.mkDefault false;
  software.requirements.dms = {
    capabilities = [ "store-package" ];
    scopes = [ ];
  };
}
