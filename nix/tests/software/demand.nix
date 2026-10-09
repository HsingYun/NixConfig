{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (import ./host-cases.nix { inherit inputs; }) mkHost allOff ownershipHost;
  valid = cfg: lib.all (a: a.assertion) cfg.assertions;
  complete = host: {
    home = host.views.home;
    # Force generated files and units, not just assertions and selected packages.
    activation = host.views.home.home.activationPackage.drvPath;
  };
  make =
    platform: preset: extra:
    complete (
      mkHost "DemandTest" {
        inherit platform;
        features =
          allOff
          // lib.optionalAttrs preset {
            vim = true;
            gpg = true;
          };
        homeConfig = {
          imports = [ extra ];
          home.stateVersion = "26.05";
        };
        systemConfig =
          if platform == "darwin" then
            { system.stateVersion = 6; }
          else
            lib.optionalAttrs (lib.hasPrefix "nixos" platform) { system.stateVersion = "26.11"; };
        hardwareConfig =
          if platform == "nixos" then
            {
              boot.initrd.enable = false;
              boot.kernel.enable = false;
              boot.loader.grub.enable = false;
            }
          else
            null;
      }
    );
  combinations = lib.genAttrs [ "arch" "darwin" ] (
    platform:
    map
      (
        preset:
        make platform preset {
          programs.vim = {
            enable = true;
            settings.number = true;
            defaultEditor = true;
          };
          programs.gpg.enable = true;
          services.gpg-agent.enable = true;
          software.requirements = {
            vim = { };
            gnupg = { };
          };
        }
      )
      [
        false
        true
      ]
  );
  agentOnly = make "arch" false { services.gpg-agent.enable = true; };
  immutableKeys = make "arch" false {
    programs.gpg = {
      enable = true;
      mutableKeys = false;
      # Evaluation fixture: no key import or build runs in this test.
      publicKeys = [ { text = "evaluation-only public key fixture"; } ];
    };
  };
  mutableKeys = make "arch" false {
    programs.gpg.enable = true;
    programs.gpg.mutableKeys = true;
  };
  # Cover independent key/trust mutability, absent keys and absent trust. A
  # nullable package is safe only when neither upstream build branch is used.
  gpgCases = lib.cartesianProduct {
    platform = [
      "arch"
      "darwin"
    ];
    mutableKeys = [
      true
      false
    ];
    mutableTrust = [
      true
      false
    ];
    keys = [
      false
      true
    ];
    trust = [
      null
      "full"
    ];
  };
  gpgCase =
    args:
    let
      test = make args.platform false {
        programs.gpg = {
          enable = true;
          inherit (args) mutableKeys mutableTrust;
          publicKeys = lib.optional args.keys {
            text = "evaluation-only fixture";
            inherit (args) trust;
          };
        };
      };
      needsBuild = args.keys && (!args.mutableKeys || (!args.mutableTrust && args.trust != null));
    in
    valid test.home
    && builtins.isString test.activation
    && (test.home.software.resolved.gnupg.provider == "nix") == needsBuild;
  ghostty =
    platform: extra:
    make platform false {
      imports = [ extra ];
      programs.ghostty.enable = true;
    };
  nativeGhostty = map (platform: ghostty platform { }) [
    "arch"
    "darwin"
  ];
  ghosttyCases = lib.cartesianProduct {
    systemd = [
      false
      true
    ];
    vim = [
      false
      true
    ];
    bat = [
      false
      true
    ];
  };
  ghosttyCase =
    args:
    let
      test = ghostty "arch" {
        programs.ghostty = {
          systemd.enable = args.systemd;
          installVimSyntax = args.vim;
          installBatSyntax = args.bat;
        };
      };
      h = test.home;
    in
    valid h
    && builtins.isString test.activation
    && (h.software.resolved.ghostty.provider == "nix") == (args.systemd || args.vim || args.bat)
    && (h.xdg.configFile ? "systemd/user/app-com.mitchellh.ghostty.service") == args.systemd;
  nixosGhostty = map (platform: ghostty platform { }) [
    "nixos"
    "nixos-wsl"
  ];
  forbiddenGhostty = ghostty "arch" {
    programs.ghostty.systemd.enable = true;
    software.providerOverrides.ghostty = "pacman";
  };
  disabled = make "arch" true {
    programs.vim.enable = false;
    programs.gpg.enable = false;
    services.gpg-agent.enable = false;
  };
  forcedNix = make "arch" true {
    software.providerOverrides.vim = "nix";
    programs.vim.enable = true;
  };
  forbidden = ownershipHost "pacman" { commonTools = true; } {
    programs.gpg.enable = true;
    services.gpg-agent.enable = true;
    software.providerOverrides.gnupg = "pacman";
  };
  scopes = ownershipHost "nix" { } {
    services.gpg-agent.enable = true;
    software.requirements.gnupg = { };
  };
  keyring =
    preset: override:
    complete (
      mkHost "KeyringDemand" {
        platform = "arch";
        features = allOff // {
          keyring = preset;
        };
        homeConfig = {
          home.stateVersion = "26.05";
          services.gnome-keyring.enable = true;
          software.providerOverrides = lib.optionalAttrs override { gnome-keyring = "nix"; };
        };
      }
    );
  keyrings = lib.cartesianProduct {
    preset = [
      false
      true
    ];
    override = [
      false
      true
    ];
  };
in
assert lib.all (test: valid test.home && builtins.isString test.activation) (
  lib.concatLists (builtins.attrValues combinations)
  ++ [
    agentOnly
    disabled
    forcedNix
  ]
);
assert lib.all (
  test:
  test.home.software.resolved.gnupg.provider == "nix"
  && test.home.programs.vim.enable
  && test.home.programs.vim.package == null
  && test.home.home.file ? ".vimrc"
  && test.home.home.sessionVariables.EDITOR == "vim"
) (lib.concatLists (builtins.attrValues combinations));
assert valid immutableKeys.home && builtins.isString immutableKeys.activation;
assert immutableKeys.home.software.resolved.gnupg.provider == "nix";
assert immutableKeys.home.home.file ? "${immutableKeys.home.programs.gpg.homedir}/pubring.kbx";
assert valid mutableKeys.home && builtins.isString mutableKeys.activation;
assert lib.all gpgCase gpgCases;
assert lib.all ghosttyCase ghosttyCases;
assert lib.all (
  test:
  valid test.home
  && builtins.isString test.activation
  && test.home.programs.ghostty.package == null
  && !test.home.programs.ghostty.systemd.enable
  && !test.home.programs.ghostty.installBatSyntax
) nativeGhostty;
assert lib.all (
  test:
  valid test.home
  && builtins.isString test.activation
  && test.home.software.resolved.ghostty.provider == "nix"
  && test.home.programs.ghostty.systemd.enable
  && test.home.programs.ghostty.installBatSyntax
  && !(test.home.software.consumers ? home-ghostty-integrations)
) nixosGhostty;
assert !(builtins.tryEval forbiddenGhostty.activation).success;
assert mutableKeys.home.software.resolved.gnupg.provider == "pacman";
assert !agentOnly.home.programs.gpg.enable;
assert agentOnly.home.software.resolved.gnupg.provider == "nix";
assert lib.hasPrefix (toString agentOnly.home.programs.gpg.package) (
  lib.concatStringsSep " " agentOnly.home.systemd.user.services.gpg-agent.Service.ExecStart
);
assert !(disabled.home.home.file ? ".vimrc");
assert !(disabled.home.systemd.user.services ? gpg-agent);
assert forcedNix.home.software.resolved.vim.provider == "nix";
assert forcedNix.home.programs.vim.package != null && !(forcedNix.home.home.file ? ".vimrc");
assert !(builtins.tryEval forbidden.home.username).success;
# A consumer's empty installation scopes cannot erase an explicit default home scope.
assert scopes.software.resolved.gnupg.scopes == [ "home" ];
assert builtins.elem scopes.programs.gpg.package scopes.home.packages;
assert lib.all (
  args:
  let
    test = keyring args.preset args.override;
  in
  valid test.home
  && builtins.isString test.activation
  && test.home.services.gnome-keyring.enable
  && (test.home.services.gnome-keyring.package == null) == !args.override
  && (test.home.xdg.configFile ? "systemd/user/gnome-keyring-daemon.socket") == !args.override
) keyrings;
{
  nativeFeatureAndDirectOptionComposition = true;
  gpgAgentContributesRuntimeConstraint = true;
  gpgBuildDemandCoversKeysAndTrust = true;
  ghosttySubfeaturesContributeDemand = true;
  nixosRetainsUpstreamGhosttyDefaults = true;
  sharedPackageOptionBoundOnce = true;
  explicitScopesSurviveConsumerDemand = true;
  incompatibleForcedProviderRejected = true;
  disabledConsumersHaveNoConfiguration = true;
  keyringUsesProviderIndependentEnable = true;
}
