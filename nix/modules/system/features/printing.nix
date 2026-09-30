{ lib, ... }:
{
  services = {
    printing.enable = lib.mkDefault true;
    avahi = {
      enable = lib.mkDefault true;
      nssmdns4 = lib.mkDefault true;
    };
  };
}
