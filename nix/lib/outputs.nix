{
  inputs,
  user,
  features ? { },
}:

let
  inherit (inputs.nixpkgs) lib;
  builders = import ./builders { inherit inputs; };
  mkHost = import ./hosts/mk-host.nix {
    inherit lib builders;
    settings = { inherit user features; };
  };
  hosts = lib.mapAttrs (name: path: mkHost name (import path)) (import ../../hosts);
  select =
    output:
    lib.mapAttrs (_: host: host.configuration) (lib.filterAttrs (_: host: host.output == output) hosts);
in
{
  nixosConfigurations = select "nixosConfigurations";
  darwinConfigurations = select "darwinConfigurations";
  homeConfigurations = select "homeConfigurations";

  checks.x86_64-linux =
    let
      pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      desktop-boundaries = import ../tests/desktop.nix { inherit inputs pkgs; };
      feature-devel = import ../tests/devel.nix { inherit pkgs; };
      feature-rules = pkgs.writeText "feature-rules.json" (
        builtins.toJSON (import ../tests/features.nix { inherit lib; })
      );
      feature-modules = pkgs.writeText "feature-modules.json" (
        builtins.toJSON (import ../tests/modules.nix { inherit inputs; })
      );
    };

  formatter = {
    x86_64-linux = inputs.nixpkgs.legacyPackages.x86_64-linux.nixfmt;
    aarch64-darwin = inputs.nixpkgs.legacyPackages.aarch64-darwin.nixfmt;
  };
}
