{ lib, ... }:
{
  wsl.usbip.enable = lib.mkDefault true;
}
