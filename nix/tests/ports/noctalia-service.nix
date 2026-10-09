{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  cases = lib.cartesianProduct {
    homeEnabled = [
      false
      true
    ];
    homeService = [
      false
      true
    ];
    systemService = [
      false
      true
    ];
    forceNix = [
      false
      true
    ];
  };
  make =
    args:
    (mkHost "NoctaliaService" {
      platform = "arch";
      features = allOff;
      systemConfig.programs.noctalia = {
        enable = args.systemService;
        systemd = {
          enable = true;
          target = "niri.service";
        };
      };
      homeConfig = {
        home.stateVersion = "26.05";
        wayland.systemd.target = "review-home.target";
        software.providerOverrides = lib.optionalAttrs (args.forceNix || args ? provider) {
          noctalia = args.provider or "nix";
        };
        programs.noctalia = {
          enable = args.homeEnabled;
          systemd.enable = args.homeService;
          settings.theme.mode = "dark";
        };
      };
    }).views.home;
  original =
    (inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        {
          home = {
            username = "test";
            homeDirectory = "/home/test";
            stateVersion = "26.05";
          };
          wayland.systemd.target = "review-home.target";
          programs.noctalia = {
            enable = true;
            systemd.enable = true;
            settings.theme.mode = "dark";
          };
        }
      ];
    }).config;
  check =
    args:
    let
      home = make args;
      homeOwns = args.homeEnabled && args.homeService;
      running = args.systemService || homeOwns;
      requested = args.homeEnabled || args.systemService;
      unit = home.systemd.user.services.noctalia or null;
      native = !(args.forceNix || homeOwns);
      label = "Noctalia service ${builtins.toJSON args}: ";
    in
    assert lib.assertMsg (lib.all (a: a.assertion) home.assertions) (label + "invalid configuration");
    assert lib.assertMsg ((unit != null) == running) (
      label + "service enablement differs from requests"
    );
    assert lib.assertMsg (
      !requested || home.software.resolved.noctalia.provider == (if native then "pacman" else "nix")
    ) (label + "service demand selected the wrong provider");
    assert lib.assertMsg (!homeOwns || unit == original.systemd.user.services.noctalia) (
      label + "the port changed the upstream-owned service"
    );
    assert lib.assertMsg (
      !running
      || homeOwns
      || (
        unit.Unit.PartOf == [ "niri.service" ]
        && unit.Install.WantedBy == [ "niri.service" ]
        && unit.Service.ExecStart == [ (home.software.resolved.noctalia.command "noctalia") ]
        && unit.Unit.ConditionEnvironment == "XDG_CURRENT_DESKTOP=niri"
      )
    ) (label + "system-owned service lost its target or selected runtime");
    assert lib.assertMsg (builtins.isString home.home.activationPackage.drvPath) (
      label + "generated configuration does not evaluate"
    );
    true;
in
assert lib.all check cases;
assert
  !(builtins.tryEval
    (make {
      homeEnabled = true;
      homeService = true;
      systemService = false;
      forceNix = false;
      provider = "pacman";
    }).home.activationPackage.drvPath
  ).success;
{
  enablementAndProviderMatrix = true;
  explicitHomeServiceMatchesUpstream = true;
  systemAndHomeRequestsHaveOneOwner = true;
  unsupportedForcedNativeServiceRejected = true;
}
