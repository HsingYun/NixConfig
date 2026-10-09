{ ... }:

{
  imports = [
    ../shared/features.nix
    ../shared/helpers.nix
    ../software/system.nix
    ../software/nixpkgs.nix
  ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
