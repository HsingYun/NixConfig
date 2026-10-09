let
  nix = package: {
    inherit package;
    # nixpkgs owns platform, license and problem policy, including explicit
    # host permissions. Derivations without that metadata retain Nix's checks.
    available = package.meta.available or true;
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
