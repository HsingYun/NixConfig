{ inputs, hosts }:
let
  inherit (inputs.nixpkgs) lib;
  hostChecks = lib.foldlAttrs (
    checks: name: host:
    let
      cfg = host.configuration;
      inherit (cfg) pkgs;
      system = pkgs.stdenv.hostPlatform.system;
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
  # The module scenarios include both platforms; evaluate them once and expose
  # their reports as native checks on each runner.
  featureRules = builtins.toJSON (import ./features/rules.nix { inherit lib; });
  featureComposition = builtins.toJSON (import ./features/composition.nix { inherit inputs; });
  softwareTests = builtins.toJSON (import ./software/integration.nix { inherit inputs; });
in
{
  inherit upstreamAssumptions;
  checks = lib.recursiveUpdate hostChecks (
    lib.genAttrs testSystems (
      system:
      let
        pkgs = inputs.nixpkgs.legacyPackages.${system};
      in
      {
        upstream-assumptions = pkgs.writeText "upstream-assumptions.json" (
          builtins.toJSON upstreamAssumptions.${system}
        );
        architecture-boundaries = import ./structure/boundaries.nix { inherit pkgs; };
        nixman = import ./apps/nixman.nix { inherit inputs pkgs; };
        nixman-installation = pkgs.writeText "nixman-installation.json" (
          builtins.toJSON (import ./apps/installation.nix { inherit inputs hosts; })
        );
        nixman-generations = pkgs.writeText "nixman-generations.json" (
          builtins.unsafeDiscardStringContext (
            builtins.toJSON (import ./apps/generations.nix { inherit inputs; })
          )
        );
        application-selection = pkgs.writeText "application-selection.json" (
          builtins.toJSON (import ./home/applications.nix { inherit inputs; })
        );
        keyring-providers = pkgs.writeText "keyring-providers.json" (
          builtins.toJSON (import ./software/keyring.nix { inherit inputs; })
        );
        platform-registration = pkgs.writeText "platform-registration.json" (
          builtins.toJSON (import ./structure/platforms.nix { inherit lib; })
        );
        native-privilege = pkgs.writeText "native-privilege.json" (
          builtins.toJSON (import ./ports/privilege.nix { inherit inputs; })
        );
        contract-types = pkgs.writeText "contract-types.json" (
          builtins.toJSON (import ./ports/contract-types.nix { inherit lib pkgs; })
        );
        platform-contract-types = pkgs.writeText "platform-contract-types.json" (
          builtins.toJSON (import ./ports/platform-types.nix { inherit inputs; })
        );
        contract-behavior = pkgs.writeText "contract-behavior.json" (
          builtins.toJSON (import ./contracts { inherit inputs; })
        );
        desktop-shells = pkgs.writeText "desktop-shells.json" (
          builtins.toJSON (import ./features/desktop-shells.nix { inherit inputs; })
        );
        feature-rules = pkgs.writeText "feature-rules.json" featureRules;
        feature-settings = pkgs.writeText "feature-settings.json" (
          builtins.toJSON (import ./home/feature-settings.nix { inherit inputs; })
        );
        chinese-input = pkgs.writeText "chinese-input.json" (
          builtins.toJSON (import ./home/chinese.nix { inherit inputs; })
        );
        host-interface = pkgs.writeText "host-interface.json" (
          builtins.toJSON (import ./hosts/interface.nix { inherit inputs hosts; })
        );
        configuration-layers = pkgs.writeText "configuration-layers.json" (
          builtins.toJSON (import ./config/layers.nix { inherit lib; })
        );
        kdl-configuration = pkgs.writeText "kdl-configuration.json" (
          builtins.toJSON (import ./config/kdl.nix { inherit inputs pkgs; })
        );
        feature-modules = pkgs.writeText "feature-modules.json" featureComposition;
        software = pkgs.writeText "software.json" softwareTests;
        native-home-conformance = pkgs.writeText "native-home-conformance.json" (
          builtins.toJSON (import ./ports/home-upstream-conformance.nix { inherit inputs; })
        );
        software-demand = pkgs.writeText "software-demand.json" (
          builtins.toJSON (import ./software/demand.nix { inherit inputs; })
        );
        software-sources = pkgs.writeText "software-sources.json" (
          builtins.toJSON (import ./software/sources.nix { inherit inputs; })
        );
        software-package-policy = pkgs.writeText "software-package-policy.json" (
          builtins.toJSON (import ./software/package-policy.nix { inherit inputs; })
        );
        login-session = pkgs.writeText "login-session.json" (
          builtins.toJSON (import ./ports/login-session.nix { inherit inputs; })
        );
        gdm-session = import ./helpers/arch/gdm-session.nix { inherit pkgs; };
        vim-runtime = import ./home/vim.nix { inherit inputs pkgs; };
        mpv-native-files = import ./home/mpv.nix { inherit inputs pkgs; };
        gpg-build-demand = import ./home/gpg-keyring.nix { inherit inputs pkgs; };
        display-manager-lifecycle = import ./helpers/arch/display-manager-lifecycle.nix { inherit pkgs; };
        software-runtime = import ./software/runtime.nix { inherit inputs pkgs; };
        mihomo-configuration = import ./ports/mihomo.nix { inherit inputs pkgs; };
        dconf-lifecycle = import ./helpers/common/dconf.nix { inherit inputs pkgs; };
        vscode-settings = import ./home/vscode-settings.nix { inherit inputs pkgs; };
        chrome-policy = import ./helpers/arch/chrome-policy.nix { inherit inputs pkgs; };
        pacman-activation = import ./helpers/arch/pacman.nix { inherit inputs pkgs; };
        native-system-profile = import ./helpers/common/system-profile-activation.nix { inherit pkgs; };
        native-units = import ./helpers/common/systemd.nix { inherit pkgs; };
        network-preflight = import ./helpers/arch/network-preflight.nix { inherit pkgs; };
        native-input-autostart = import ./helpers/arch/autostart.nix { inherit inputs pkgs; };
        native-niri-config = import ./helpers/arch/niri.nix { inherit inputs pkgs; };
        native-noctalia-config = import ./helpers/arch/noctalia.nix { inherit inputs pkgs; };
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
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
  );
}
