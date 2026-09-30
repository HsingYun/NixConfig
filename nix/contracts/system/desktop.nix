# The public desktop contract remains a composition of smaller service schemas.
{ ... }: {
  imports = [
    ./services/desktop.nix
    ./services/display-manager.nix
    ./services/network.nix
    ./services/bluetooth.nix
    ./services/audio.nix
    ./services/power.nix
    ./services/storage.nix
  ];
}
