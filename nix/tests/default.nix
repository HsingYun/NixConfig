{ inputs, hosts }:
let
  inherit (inputs.nixpkgs) lib;
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
  featureRules = builtins.toJSON (import ./features/rules.nix { inherit lib; });
  featureComposition = builtins.toJSON (import ./features/composition.nix { inherit inputs; });
  softwareTests = builtins.toJSON (import ./software/integration.nix { inherit inputs; });
in
lib.recursiveUpdate hostChecks (
  lib.genAttrs testSystems (
    system:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    in
    {
      architecture-boundaries = import ./structure/boundaries.nix { inherit pkgs; };
      platform-registration = pkgs.writeText "platform-registration.json" (
        builtins.toJSON (import ./structure/platforms.nix { inherit lib; })
      );
      feature-rules = pkgs.writeText "feature-rules.json" featureRules;
      feature-modules = pkgs.writeText "feature-modules.json" featureComposition;
      software = pkgs.writeText "software.json" softwareTests;
      software-sources = pkgs.writeText "software-sources.json" (
        builtins.toJSON (import ./software/sources.nix { inherit inputs; })
      );
      vim-runtime = import ./home/vim.nix { inherit inputs pkgs; };
      display-manager-lifecycle = import ./helpers/arch/display-manager-lifecycle.nix { inherit pkgs; };
      software-runtime = import ./software/runtime.nix { inherit inputs pkgs; };
      dconf-lifecycle = import ./helpers/common/dconf.nix { inherit inputs pkgs; };
      vscode-settings = import ./home/vscode-settings.nix { inherit inputs pkgs; };
      pacman-activation = import ./helpers/arch/pacman.nix { inherit inputs pkgs; };
    }
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      desktop-boundaries = import ./home/desktop.nix { inherit inputs pkgs; };
      native-input-autostart = import ./helpers/arch/autostart.nix { inherit pkgs; };
      pacman-migration = import ./helpers/arch/pacman-migration.nix { inherit inputs pkgs; };
      greeter-session = import ./helpers/common/greeter-session.nix { inherit pkgs; };
      native-units = import ./helpers/arch/native-units.nix { inherit pkgs; };
      owned-root-file = import ./helpers/common/owned-root-file.nix { inherit inputs pkgs; };
      launcher-native = import ./helpers/arch/launcher-native.nix { inherit pkgs; };
      feature-devel = import ./software/devel.nix { inherit pkgs; };
      chrome-policy = import ./helpers/arch/chrome-policy.nix { inherit inputs pkgs; };
      display-manager-activation = import ./helpers/arch/display-manager-activation.nix {
        inherit inputs pkgs;
      };
    }
  )
)
