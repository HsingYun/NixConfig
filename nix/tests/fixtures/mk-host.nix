{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  mkHost = import ../../lib/hosts/mk-host.nix {
    inherit lib;
    builders = import ../../lib/builders { inherit inputs; };
    settings = {
      features = { };
      user = {
        username = "test";
        git = {
          name = "Test";
          email = "test@example.invalid";
        };
      };
    };
  };
in
{
  rawMkHost = mkHost;
  mkHost = import ./host-fixture.nix { inherit lib mkHost; };
}
