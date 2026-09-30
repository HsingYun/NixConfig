{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  contracts = import ../../contracts;
  platforms = (import ../../lib/platforms).definitions;
  observations = import ./observations { inherit lib; };
  observe =
    name: cfg:
    let
      shared = cases.${name}.observe or null;
      implementation = observations.${cfg.platform}.${name} or null;
      normalize =
        prefix: observer:
        if observer == null then
          { }
        else
          let
            value = observer cfg;
          in
          if builtins.isBool value then
            { ${prefix} = value; }
          else
            lib.mapAttrs' (key: effect: lib.nameValuePair "${prefix}.${key}" effect) value;
    in
    normalize "shared" shared // normalize "port" implementation;
  oracle = import ./oracle.nix { inherit lib; };
  cases = import ./cases.nix { inherit lib; };
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  makeDefinition =
    platform: definition:
    let
      bootstrap = import ../fixtures/platform.nix { port = platforms.${platform}; };
      host = mkHost "ContractBehavior" {
        inherit platform;
        features = allOff;
        inherit (bootstrap) hardwareConfig;
        systemConfig.imports = [
          bootstrap.systemConfig
          { config = definition.system or { }; }
        ];
        homeConfig = {
          imports = [ { config = definition.home or { }; } ];
          home.stateVersion = "26.05";
        };
      };
    in
    assert lib.assertMsg (!(definition ? features))
      "Contract tests must configure public interfaces directly; feature presets belong in feature tests.";
    {
      inherit platform;
      port = platforms.${platform};
      inherit (host.views) system home;
    };
  make =
    platform: name: enabled:
    makeDefinition platform (
      cases.${name}.configure {
        inherit enabled;
        port = platforms.${platform};
      }
    );
  validate = cfg: lib.all (a: a.assertion) (cfg.system.assertions ++ cfg.home.assertions);
  check =
    platform: port:
    assert lib.assertMsg
      (lib.all (name: cases.${name} ? observe || observations.${platform} ? ${name}) port.contracts)
      "Port ${platform}: every declared contract requires a shared or platform-specific behavior observer.";
    # Each contract is exercised directly and in isolation. Feature tests
    # separately cover presets and their composition.
    lib.genAttrs port.contracts (
      name:
      let
        on = make platform name true;
        off = make platform name false;
      in
      assert lib.assertMsg (
        validate on && validate off
      ) "Contract behavior fixture invalid on ${platform}: ${name}";
      assert lib.assertMsg (oracle true (
        observe name on
      )) "Contract ${name}: enabling it produced no expected effect on ${platform}.";
      assert lib.assertMsg (oracle false (
        observe name off
      )) "Contract ${name}: disabling it retained its effect on ${platform}.";
      assert lib.all (
        scenarioName:
        let
          scenario = cases.${name}.scenarios.${scenarioName};
          cfg = makeDefinition platform scenario.configure;
        in
        assert lib.assertMsg (validate cfg)
          "Contract scenario invalid on ${platform}: ${name}/${scenarioName}";
        assert lib.assertMsg (scenario.verify cfg)
          "Contract scenario failed on ${platform}: ${name}/${scenarioName}";
        true
      ) (builtins.attrNames (cases.${name}.scenarios or { }));
      true
    );

in
assert lib.assertMsg (
  builtins.attrNames observations == builtins.attrNames platforms
) "Every registered port must select its contract behavior observers.";
assert lib.assertMsg (
  builtins.attrNames cases == builtins.attrNames contracts
) "Every public contract must register a shared behavior case; remove stale cases too.";
{
  platforms = lib.mapAttrs check platforms;
  # Remove each backend independently; both incomplete installation and stale
  # service ownership must be detected by the same oracle used above.
  detectsPartialPrinting =
    let
      cfg = make "arch" "system.printing" true;
      broken =
        change:
        cfg
        // {
          system = cfg.system // {
            native = cfg.system.native // change;
          };
        };
      variants = [
        (broken { requiredPackages = [ ]; })
        (broken {
          systemd = cfg.system.native.systemd // {
            units = [ ];
          };
        })
      ];
    in
    assert lib.all (c: !(oracle true (observe "system.printing" c))) variants;
    assert lib.all (c: !(oracle false (observe "system.printing" c))) variants;
    true;
}
