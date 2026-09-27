{ lib, ... }:

{
  services.pcscd.enable = lib.mkDefault true;
}
