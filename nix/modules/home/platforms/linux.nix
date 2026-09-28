{ pkgs, ... }:

{
  targets.genericLinux.enable = true;

  home.packages = (import ../../../packages/base-cli.nix { inherit pkgs; }) ++ [ pkgs.efibootmgr ];
}
