{ lib, ... }: {
  imports = [ ./niri.nix ];
  programs.noctalia = {
    enable = lib.mkDefault true;
    systemd.target = lib.mkDefault "niri.service";
  };
}
