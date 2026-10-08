{ inputs, hosts }:
let
  inherit (inputs.nixpkgs) lib;
  base = inputs.nixpkgs.legacyPackages.aarch64-darwin;
  namespaceProbe =
    (base.extend (
      _: _: {
        nixman = base.hello;
        nixconfig.nixman = base.hello;
        hsingyun = {
          other = base.emptyDirectory;
          nixconfig.other = base.emptyDirectory;
        };
      }
    )).extend
      (import ../../apps/overlay.nix { inherit inputs; });
  conflictProbe = (base.extend (_: _: { hsingyun.nixconfig.nixman = base.hello; })).extend (
    import ../../apps/overlay.nix { inherit inputs; }
  );
in
assert namespaceProbe.nixman == base.hello;
assert namespaceProbe.nixconfig.nixman == base.hello;
assert namespaceProbe.hsingyun.other == base.emptyDirectory;
assert namespaceProbe.hsingyun.nixconfig.other == base.emptyDirectory;
assert namespaceProbe.hsingyun.nixconfig.nixman.pname == "nixman";
assert !(builtins.tryEval conflictProbe.hsingyun.nixconfig.nixman.pname).success;
lib.mapAttrs (
  name: host:
  let
    home = host.views.home;
    selected = home.software.resolved.nixman;
    expected = import ../../apps/nixman {
      pkgs = host.configuration.pkgs;
      homeManager =
        inputs.home-manager.packages.${host.configuration.pkgs.stdenv.hostPlatform.system}.home-manager;
    };
    installed = lib.filter (package: package.drvPath == selected.package.drvPath) home.home.packages;
  in
  assert selected.provider == "nix";
  assert builtins.length installed == 1;
  assert (builtins.head installed).drvPath == selected.package.drvPath;
  assert selected.package.drvPath == expected.drvPath;
  assert selected.package.pname == "nixman";
  assert selected.package.meta.mainProgram == "nixman";
  {
    inherit name;
    inherit (selected) provider;
    package = builtins.unsafeDiscardStringContext selected.package.drvPath;
  }
) hosts
