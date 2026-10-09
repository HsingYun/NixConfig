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
  appSystems = [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
  ];
  tests = import ../tests {
    inherit
      inputs
      hosts
      packages
      apps
      formatter
      ;
  };
  packages = lib.genAttrs appSystems (
    system:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system}.extend (
        import ../apps/overlay.nix { inherit inputs; }
      );
    in
    {
      inherit (pkgs.hsingyun.nixconfig) nixman;
      default = pkgs.hsingyun.nixconfig.nixman;
    }
  );

  apps = lib.mapAttrs (_: value: rec {
    nixman = {
      type = "app";
      program = "${value.nixman}/bin/nixman";
      meta.description = "Preview updates and manage Nix system and home generations";
    };
    default = nixman;
  }) packages;

  formatter = {
    x86_64-linux = inputs.nixpkgs.legacyPackages.x86_64-linux.nixfmt;
    aarch64-darwin = inputs.nixpkgs.legacyPackages.aarch64-darwin.nixfmt;
  };

in
{
  inherit packages apps formatter;

  nixosConfigurations = select "nixosConfigurations";
  darwinConfigurations = select "darwinConfigurations";
  homeConfigurations = select "homeConfigurations";
  lib = {
    # This diagnostic entry point must remain independent of host evaluation.
    inherit (tests) upstreamAssumptions ciMatrix;
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

  inherit (tests) checks;
}
