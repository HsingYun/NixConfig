{
  inputs,
  hosts,
  packages,
  apps,
  formatter,
}:
let
  inherit (inputs.nixpkgs) lib;
  hostChecks = lib.foldlAttrs (
    checks: name: host:
    let
      cfg = host.configuration;
      inherit (cfg) pkgs;
      inherit (host) system;
      home = host.views.home;
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
          assert lib.assertMsg (
            pkgs.stdenv.hostPlatform.system == system
          ) "Host ${name}: evaluated platform differs from the declared system.";
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
  upstreamAssumptions = lib.genAttrs testSystems (
    system:
    import ./upstream-assumptions.nix {
      inherit inputs;
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    }
  );
  # Public-interface and cross-platform evaluation scenarios run once on Linux.
  evaluationReports = {
    ci-plan = builtins.toJSON {
      coverage = ciMatrix;
      regressions = import ./ci/test-plan.nix { inherit lib; };
    };
    flake-outputs = import ./structure/flake-outputs.nix {
      inherit
        lib
        packages
        apps
        formatter
        ;
    };
    application-selection = builtins.toJSON (import ./home/applications.nix { inherit inputs; });
    chinese-input = builtins.toJSON (import ./home/chinese.nix { inherit inputs; });
    configuration-layers = builtins.toJSON (import ./config/layers.nix { inherit lib; });
    contract-behavior = builtins.toJSON (import ./contracts { inherit inputs; });
    desktop-shells = builtins.toJSON (import ./features/desktop-shells.nix { inherit inputs; });
    feature-modules = builtins.toJSON (import ./features/composition.nix { inherit inputs; });
    feature-rules = builtins.toJSON (import ./features/rules.nix { inherit lib; });
    feature-settings = builtins.toJSON (import ./home/feature-settings.nix { inherit inputs; });
    host-interface = builtins.toJSON (import ./hosts/interface.nix { inherit inputs hosts; });
    keyring-providers = builtins.toJSON (import ./software/keyring.nix { inherit inputs; });
    login-session = builtins.toJSON (import ./ports/login-session.nix { inherit inputs; });
    native-home-conformance = builtins.toJSON (
      import ./ports/home-upstream-conformance.nix { inherit inputs; }
    );
    native-privilege = builtins.toJSON (import ./ports/privilege.nix { inherit inputs; });
    nixman-generations = builtins.unsafeDiscardStringContext (
      builtins.toJSON (import ./apps/generations.nix { inherit inputs; })
    );
    nixman-installation = builtins.toJSON (import ./apps/installation.nix { inherit inputs hosts; });
    platform-contract-types = builtins.toJSON (import ./ports/platform-types.nix { inherit inputs; });
    platform-registration = builtins.toJSON (import ./structure/platforms.nix { inherit lib; });
    software = builtins.toJSON (import ./software/integration.nix { inherit inputs; });
    software-demand = builtins.toJSON (import ./software/demand.nix { inherit inputs; });
    software-package-policy = builtins.toJSON (
      import ./software/package-policy.nix { inherit inputs; }
    );
    software-sources = builtins.toJSON (import ./software/sources.nix { inherit inputs; });
  };
  checks = lib.recursiveUpdate hostChecks (
    lib.genAttrs testSystems (
      system:
      let
        pkgs = inputs.nixpkgs.legacyPackages.${system};
      in
      {
        # These checks build or run platform-sensitive artifacts on each native runner.
        upstream-assumptions = pkgs.writeText "upstream-assumptions.json" (
          builtins.toJSON upstreamAssumptions.${system}
        );
        nixman = import ./apps/nixman.nix { inherit inputs pkgs; };
        vim-runtime = import ./home/vim.nix { inherit inputs pkgs; };
        mpv-native-files = import ./home/mpv.nix { inherit inputs pkgs; };
        gpg-build-demand = import ./home/gpg-keyring.nix { inherit inputs pkgs; };
        software-runtime = import ./software/runtime.nix { inherit inputs pkgs; };
        vscode-settings = import ./home/vscode-settings.nix { inherit inputs pkgs; };
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux (
        lib.mapAttrs (name: report: pkgs.writeText "${name}.json" report) evaluationReports
        // {
          nixman-unit = import ./apps/nixman-unit.nix { inherit pkgs; };
          architecture-boundaries = import ./structure/boundaries.nix { inherit pkgs; };
          contract-types = pkgs.writeText "contract-types.json" (
            builtins.toJSON (import ./ports/contract-types.nix { inherit lib pkgs; })
          );
          kdl-configuration = pkgs.writeText "kdl-configuration.json" (
            builtins.toJSON (import ./config/kdl.nix { inherit inputs pkgs; })
          );
          gdm-session = import ./helpers/arch/gdm-session.nix { inherit pkgs; };
          display-manager-lifecycle = import ./helpers/arch/display-manager-lifecycle.nix { inherit pkgs; };
          mihomo-configuration = import ./ports/mihomo.nix { inherit inputs pkgs; };
          dconf-lifecycle = import ./helpers/common/dconf.nix { inherit inputs pkgs; };
          chrome-policy = import ./helpers/arch/chrome-policy.nix { inherit inputs pkgs; };
          pacman-activation = import ./helpers/arch/pacman.nix { inherit inputs pkgs; };
          native-system-profile = import ./helpers/common/system-profile-activation.nix { inherit pkgs; };
          native-units = import ./helpers/common/systemd.nix { inherit pkgs; };
          network-preflight = import ./helpers/arch/network-preflight.nix { inherit pkgs; };
          native-input-autostart = import ./helpers/arch/autostart.nix { inherit inputs pkgs; };
          native-niri-config = import ./helpers/arch/niri.nix { inherit inputs pkgs; };
          native-noctalia-config = import ./helpers/arch/noctalia.nix { inherit inputs pkgs; };
          desktop-autostart = import ./home/autostart.nix { inherit inputs pkgs hosts; };
          mihomo-service = import ./ports/mihomo-vm.nix { inherit inputs pkgs; };
          native-user-units = import ./home/native-systemd.nix { inherit inputs pkgs; };
          native-system-backend = import ./helpers/common/system-backend.nix { inherit inputs pkgs; };
          native-system-integration = import ./home/native-system.nix { inherit inputs pkgs; };
          noctalia-configuration = import ./home/noctalia.nix { inherit inputs pkgs; };
          niri-dms-configuration = import ./home/niri-dms.nix { inherit inputs pkgs; };
          desktop-boundaries = import ./home/desktop.nix { inherit inputs pkgs; };
          pacman-migration = import ./helpers/arch/pacman-migration.nix { inherit inputs pkgs; };
          greeter-session = import ./helpers/common/greeter-session.nix { inherit pkgs; };
          native-systemd-vm = import ./helpers/arch/native-systemd-vm.nix { inherit inputs pkgs; };
          owned-root-file = import ./helpers/common/owned-root-file.nix { inherit inputs pkgs; };
          launcher-native = import ./helpers/arch/launcher-native.nix { inherit pkgs; };
          feature-devel = import ./software/devel.nix { inherit pkgs; };
          display-manager-activation = import ./helpers/arch/display-manager-activation.nix {
            inherit inputs pkgs;
          };
        }
      )
    )
  );
  ciMatrix = import ./ci { inherit lib checks hostChecks; };
in
{
  inherit upstreamAssumptions checks ciMatrix;
}
