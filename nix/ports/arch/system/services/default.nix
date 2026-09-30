{ ... }: {
  imports = [
    ./desktop.nix
    ./network.nix
    ./bluetooth.nix
    ./audio.nix
    ./power.nix
    ./storage.nix
    ./printing.nix
    ./avahi.nix
    ./firmware.nix
    ./smartcard.nix
    ./chrome.nix
  ];
}
