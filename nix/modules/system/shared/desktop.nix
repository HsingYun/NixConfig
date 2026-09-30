{
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./network.nix ];

  networking.networkmanager.enable = lib.mkDefault true;

  security.rtkit.enable = lib.mkDefault true;
  services = {
    pipewire = {
      enable = lib.mkDefault true;
      alsa.enable = lib.mkDefault true;
      pulse.enable = lib.mkDefault true;
    };
    upower.enable = lib.mkDefault true;
    udisks2.enable = lib.mkDefault true;
    gvfs.enable = lib.mkDefault true;
  };

  hardware.bluetooth.enable = lib.mkDefault true;

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];
}
