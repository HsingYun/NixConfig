{ lib, ... }: {
  options.services = {
    udisks2.enable = lib.mkEnableOption "UDisks";
    gvfs.enable = lib.mkEnableOption "GVfs";
  };
}
