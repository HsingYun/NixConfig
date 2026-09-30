{ ... }:

{
  imports = [
    ../software/system.nix
    ../software/nixpkgs.nix
  ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
