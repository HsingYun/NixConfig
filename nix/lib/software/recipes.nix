{ pkgs }:
let
  inherit (pkgs) lib;
  nix = package: {
    inherit package;
    available =
      lib.meta.availableOn pkgs.stdenv.hostPlatform package && !(package.meta.broken or false);
    capabilities = [ "store-package" ];
  };
  font =
    package:
    nix package
    // {
      capabilities = [
        "store-package"
        "font"
      ];
    };
  brew = name: {
    inherit name;
    type = "brew";
  };
  cask = name: {
    inherit name;
    type = "cask";
  };
in
{
  inherit
    nix
    font
    brew
    cask
    ;
  pacman = name: {
    inherit name;
    type = "package";
  };
  aur = name: {
    inherit name;
    type = "aur";
  };
}
