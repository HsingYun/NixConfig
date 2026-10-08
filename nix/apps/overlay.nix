{ inputs }:
final: prev:
let
  owner = prev.hsingyun or { };
  repository = owner.nixconfig or { };
in
{
  hsingyun = owner // {
    nixconfig = repository // {
      nixman =
        assert final.lib.assertMsg (
          !(repository ? nixman)
        ) "NixConfig: pkgs.hsingyun.nixconfig.nixman already exists; refusing to overwrite it.";
        import ./nixman {
          pkgs = final;
          homeManager = inputs.home-manager.packages.${final.stdenv.hostPlatform.system}.home-manager;
        };
    };
  };
}
