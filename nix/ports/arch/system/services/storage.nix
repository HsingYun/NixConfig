{ config, lib, ... }: {
  imports = [ ../../../../contracts/system/services/storage.nix ];
  config = lib.mkMerge [
    (lib.mkIf config.services.udisks2.enable { native.requiredPackages = [ "udisks2" ]; })
    (lib.mkIf config.services.gvfs.enable { native.requiredPackages = [ "gvfs" ]; })
  ];
}
