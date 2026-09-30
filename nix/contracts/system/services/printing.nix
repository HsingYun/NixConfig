{ lib, ... }: { options.services.printing.enable = lib.mkEnableOption "CUPS printing"; }
