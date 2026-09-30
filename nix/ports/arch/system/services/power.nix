{ config, lib, ... }: {
  imports = [ ../../../../contracts/system/services/power.nix ];
  config = lib.mkIf config.services.upower.enable { native.requiredPackages = [ "upower" ]; };
}
