{ pkgs, ... }:

{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.systemPackages = import ../../packages/base-cli.nix { inherit pkgs; };
}
