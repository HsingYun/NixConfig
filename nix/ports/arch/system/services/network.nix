{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ../../../../contracts/system/services/network.nix ];
  config = lib.mkIf config.networking.networkmanager.enable {
    native = {
      requiredPackages = [ "networkmanager" ];
      systemd = {
        units = [ "NetworkManager.service" ];
        enableOnly = [ "NetworkManager-wait-online.service" ];
      };
      preflight.checkNativeDesktopNetwork = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        ${pkgs.python3}/bin/python ${../../../../assets/helpers/arch/network-preflight.py}
      '';
    };
  };
}
