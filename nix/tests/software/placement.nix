{ inputs, ownershipHost }:
let
  inherit (inputs.nixpkgs) lib;
  identities = [
    "vim"
    "mpv"
    "vscode"
  ];
  home = ownershipHost "nix" (lib.genAttrs identities (_: true)) {
    software.requirements = lib.genAttrs identities (_: {
      scopes = [
        "home"
        "system"
      ];
    });
  };
  disabled = ownershipHost "nix" { vim = true; } {
    software.requirements.vim.scopes = [ "system" ];
    programs.vim.enable = false;
  };
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  materialize = import ../../lib/software/materialize.nix { inherit lib; };
  resolve = import ../../lib/software/resolve.nix { inherit lib; };
  scopes = [
    [ ]
    [ "home" ]
    [ "system" ]
    [
      "home"
      "system"
    ]
  ];
  planFor =
    requested: installed:
    materialize {
      selection = resolve {
        catalog.test.nix.package = pkgs.hello;
        requirements.test.scopes = requested;
        packageManager = "nix";
        platform = "arch";
      };
      runtimeArtifacts = lib.optionalAttrs (installed != [ ]) {
        first = {
          software = "test";
          package = pkgs.hello;
          scopes = installed;
        };
        second = {
          software = "test";
          package = pkgs.hello;
          scopes = installed;
        };
      };
    };
  verifyScopes =
    requested: installed:
    let
      plan = planFor requested installed;
      expected = lib.subtractLists installed requested;
    in
    lib.all
      (scope: (plan.installations.nix.${scope + "Packages"} != [ ]) == builtins.elem scope expected)
      [
        "home"
        "system"
      ];
  incompatible = materialize {
    selection = resolve {
      catalog.test.nix.package = pkgs.hello;
      requirements.test = { };
      packageManager = "nix";
      platform = "arch";
    };
    runtimeArtifacts = {
      first = {
        software = "test";
        package = pkgs.hello;
        scopes = [ "home" ];
      };
      second = {
        software = "test";
        package = pkgs.nano;
        scopes = [ "system" ];
      };
    };
  };
  verify =
    name:
    let
      entry = home.software.resolved.${name};
      runtime = toString entry.runtimePackage;
    in
    assert lib.all (scope: builtins.elem scope entry.scopes) [
      "home"
      "system"
    ];
    assert builtins.elem runtime (map toString home.home.packages);
    assert builtins.elem runtime (map toString home.hostSystem.environment.systemPackages);
    assert !(builtins.elem runtime (map toString home.software.plan.installations.nix.homePackages));
    assert runtime != toString entry.package || name == "vscode";
    true;
in
assert lib.all (a: a.assertion) (home.assertions ++ home.hostSystem.assertions);
assert lib.all verify identities;
assert lib.all (requested: lib.all (verifyScopes requested) scopes) scopes;
assert !(builtins.tryEval (toString incompatible.resolved.test.runtimePackage)).success;
assert
  toString disabled.software.resolved.vim.runtimePackage
  == toString disabled.software.resolved.vim.package;
assert builtins.elem (toString disabled.software.resolved.vim.package) (
  map toString disabled.hostSystem.environment.systemPackages
);
{
  upstreamRuntimeInstalledInEveryRequestedScope = identities;
  allScopeAndOwnershipCombinations = 16;
  incompatibleConsumerArtifactsRejected = true;
  independentSystemRequestSurvivesInactiveHomeConsumer = true;
}
