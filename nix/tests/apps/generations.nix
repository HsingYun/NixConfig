{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  verify =
    platform: backend:
    let
      host = mkHost "NixmanTest" (
        {
          inherit platform;
          features = allOff;
          homeConfig = {
            home.stateVersion = "26.05";
            home.file."nixman-probe".text = "fixture";
          };
          systemConfig =
            if platform == "darwin" then
              {
                system.stateVersion = 6;
                homebrew.brews = [ "watch" ];
              }
            else if platform == "nixos" then
              {
                system.stateVersion = "26.05";
              }
            else
              { };
        }
        // lib.optionalAttrs (platform == "nixos") {
          hardwareConfig = {
            boot.loader.grub.enable = false;
            fileSystems."/" = {
              device = "/dev/test";
              fsType = "ext4";
            };
          };
        }
      );
      source = {
        flake = "github:example/config#NixmanTest";
        configuration = "NixmanTest";
        lockedReference = "fixture";
        revision = null;
        sourceHash = "fixture";
      };
      extended = host.configuration.extendModules {
        modules = [ (import ../../apps/nixman/templates/generation.nix { inherit source backend; }) ];
      };
      config = extended.config;
      record = import ../../apps/nixman/templates/manifest.nix {
        inherit
          source
          backend
          config
          lib
          ;
      };
      target =
        if backend == "home-manager" then
          extended.activationPackage
        else if backend == "darwin" then
          extended.system
        else
          config.system.build.toplevel;
      homeDirectory = if backend == "darwin" then "/Users/test" else "/home/test";
      home = if backend == "home-manager" then config else config.home-manager.users.test;
    in
    assert record.schema == 1;
    assert home.software.resolved.nixman.provider == "nix";
    assert
      lib.count (
        package: package.drvPath == home.software.resolved.nixman.package.drvPath
      ) home.home.packages == 1;
    assert record.flake == source.flake;
    assert record.managedFiles ? "${homeDirectory}/nixman-probe";
    assert backend != "darwin" || builtins.elem "watch" record.native.homebrew.brews;
    assert backend != "home-manager" || builtins.isList record.native.pacman.packages;
    {
      inherit record;
      drvPath = builtins.unsafeDiscardStringContext target.drvPath;
    };
in
{
  nixos = verify "nixos" "nixos";
  darwin = verify "darwin" "darwin";
  homeManager = verify "arch" "home-manager";
}
