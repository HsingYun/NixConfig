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
  hostChecks = lib.foldlAttrs (
    checks: name: host:
    let
      cfg = host.configuration;
      inherit (cfg) pkgs;
      system = pkgs.stdenv.hostPlatform.system;
      home =
        if host.output == "homeConfigurations" then
          cfg.config
        else
          cfg.config.home-manager.users.${host.username};
      target =
        if host.output == "nixosConfigurations" then
          cfg.config.system.build.toplevel
        else if host.output == "darwinConfigurations" then
          cfg.system
        else
          cfg.activationPackage;
    in
    lib.recursiveUpdate checks {
      ${system} = {
        "host-${name}" = pkgs.writeText "host-${name}-evaluation.json" (
          builtins.toJSON {
            inherit name system;
            # Force system assertions without building the whole machine.
            drvPath = builtins.unsafeDiscardStringContext target.drvPath;
          }
        );
        # Evaluation alone cannot catch collisions in buildEnv. Assemble the
        # actual package set for every host on its native CI runner.
        "home-profile-${name}" = home.home.path;
      };
    }
  ) { } hosts;
  testSystems = [
    "x86_64-linux"
    "aarch64-darwin"
  ];
  # The module scenarios include both platforms; evaluate them once and expose
  # their reports as native checks on each runner.
  featureRules = builtins.toJSON (import ../tests/features.nix { inherit lib; });
  featureModules = builtins.toJSON (import ../tests/modules.nix { inherit inputs; });
  softwareTests = builtins.toJSON (import ../tests/software.nix { inherit inputs; });
  softwarePlans = lib.mapAttrs (
    _: host:
    let
      cfg = host.configuration.config;
    in
    (if host.output == "homeConfigurations" then cfg else cfg.home-manager.users.${host.username})
    .software.plan
  ) hosts;

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

  checks = lib.recursiveUpdate hostChecks (
    lib.genAttrs testSystems (
      system:
      let
        pkgs = inputs.nixpkgs.legacyPackages.${system};
      in
      {
        feature-rules = pkgs.writeText "feature-rules.json" featureRules;
        feature-modules = pkgs.writeText "feature-modules.json" featureModules;
        software = pkgs.writeText "software.json" softwareTests;
        vim-runtime = import ../tests/vim.nix { inherit inputs pkgs; };
        software-runtime = import ../tests/software-runtime.nix { inherit inputs pkgs; };
        seed-json-settings = import ../tests/seed-json-settings.nix { inherit pkgs; };
        pacman-activation = import ../tests/pacman.nix { inherit inputs pkgs; };
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        desktop-boundaries = import ../tests/desktop.nix { inherit inputs pkgs; };
        native-input-autostart = import ../tests/autostart.nix { inherit pkgs; };
        pacman-migration = import ../tests/pacman-migration.nix { inherit inputs pkgs; };
        greeter-session = import ../tests/greeter-session.nix { inherit pkgs; };
        dconf-lifecycle = import ../tests/dconf.nix { inherit pkgs; };
        native-units = import ../tests/native-units.nix { inherit pkgs; };
        owned-root-file = import ../tests/owned-root-file.nix { inherit inputs pkgs; };
        launcher-native = import ../tests/launcher-native.nix { inherit pkgs; };
        feature-devel = import ../tests/devel.nix { inherit pkgs; };
        chrome-policy = import ../tests/chrome-policy.nix { inherit inputs pkgs; };
        display-manager-activation = import ../tests/display-manager-activation.nix {
          inherit inputs pkgs;
        };
      }
    )
  );

  formatter = {
    x86_64-linux = inputs.nixpkgs.legacyPackages.x86_64-linux.nixfmt;
    aarch64-darwin = inputs.nixpkgs.legacyPackages.aarch64-darwin.nixfmt;
  };
}
