{ lib, ... }: { options.services.fwupd.enable = lib.mkEnableOption "firmware updates"; }
