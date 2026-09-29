# Deployment platforms, distinct from Nix CPU/OS systems such as x86_64-linux.
let
  definitions = rec {
    arch = {
      managesSystem = false;
      output = "homeConfigurations";
      builder = "homeManager";
      packageManager = "pacman";
      defaultSystem = "x86_64-linux";
      systemModules = [ ];
      homeModules = [ ../../modules/home/platforms/arch ];
    };
    nixos = {
      managesSystem = true;
      output = "nixosConfigurations";
      builder = "nixos";
      packageManager = "nix";
      defaultSystem = "x86_64-linux";
      systemModules = [ ../../modules/system/platforms/nixos.nix ];
      homeModules = [ ];
    };
    nixos-wsl = nixos // {
      systemModules = [ ../../modules/system/platforms/nixos-wsl.nix ];
    };
    darwin = {
      managesSystem = true;
      output = "darwinConfigurations";
      builder = "darwin";
      packageManager = "homebrew";
      defaultSystem = "aarch64-darwin";
      systemModules = [ ../../modules/system/platforms/darwin.nix ];
      homeModules = [ ];
    };
  };
in
{
  inherit definitions;
  all = builtins.attrNames definitions;
  linux = [
    "arch"
    "nixos"
    "nixos-wsl"
  ];
  nixos = [
    "nixos"
    "nixos-wsl"
  ];
  desktops = [
    "arch"
    "nixos"
  ];
}
