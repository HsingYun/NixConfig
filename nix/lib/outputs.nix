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
  softwarePlans = lib.mapAttrs (_: host: host.views.home.software.plan) hosts;

in
{
  nixosConfigurations = select "nixosConfigurations";
  darwinConfigurations = select "darwinConfigurations";
  homeConfigurations = select "homeConfigurations";
  lib = {
    softwarePlans = lib.mapAttrs (_: plan: plan.report) softwarePlans;
    softwareManifests = lib.mapAttrs (_: plan: {
      inherit (plan) manager externalReport;
      inherit (plan.installations) homebrew pacman;
      nix = {
        delegated = map lib.getName plan.installations.nix.modulePackages;
        home = map lib.getName plan.installations.nix.homePackages;
        system = map lib.getName plan.installations.nix.systemPackages;
      };
    }) softwarePlans;
  };

  checks = import ../tests { inherit inputs hosts; };

  formatter = {
    x86_64-linux = inputs.nixpkgs.legacyPackages.x86_64-linux.nixfmt;
    aarch64-darwin = inputs.nixpkgs.legacyPackages.aarch64-darwin.nixfmt;
  };
}
