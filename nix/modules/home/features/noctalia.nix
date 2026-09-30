{ config, lib, ... }: {
  imports = [ ../shared/desktop.nix ];
  programs.noctalia = {
    enable = lib.mkDefault true;
    # The platform system capability owns session startup.
    systemd.enable = lib.mkDefault false;
    inherit (config.features.desktop.noctalia) settings;
  };
}
