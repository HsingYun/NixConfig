{ ... }:

{
  imports = [ ../software/system.nix ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
