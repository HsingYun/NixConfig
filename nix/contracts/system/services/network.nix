{ lib, ... }: { options.networking.networkmanager.enable = lib.mkEnableOption "NetworkManager"; }
