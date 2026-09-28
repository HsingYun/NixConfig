{
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./network.nix ];

  networking.networkmanager.enable = lib.mkDefault true;

  security.rtkit.enable = lib.mkDefault true;
  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
  };

  hardware.bluetooth.enable = lib.mkDefault true;
  services.upower.enable = lib.mkDefault true;
  services.udisks2.enable = lib.mkDefault true;
  services.gvfs.enable = lib.mkDefault true;

  services.printing.enable = lib.mkDefault true;
  services.avahi = {
    enable = lib.mkDefault true;
    nssmdns4 = lib.mkDefault true;
  };
  services.fwupd.enable = lib.mkDefault true;

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];
}
