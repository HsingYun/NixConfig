{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  resolve = import ../../lib/software/resolve.nix {
    inherit lib;
    platformProviders = (import ../../lib/platforms).packageProviders;
  };
  make =
    platform: args:
    let
      pkgs =
        inputs.nixpkgs.legacyPackages.${if platform == "darwin" then "aarch64-darwin" else "x86_64-linux"};
    in
    resolve (
      {
        inherit pkgs platform;
        catalog = import ../../lib/software/catalog.nix { inherit pkgs; };
        requirements = { };
        packageManager = if platform == "darwin" then "homebrew" else "pacman";
      }
      // args
    );
  mac = make "darwin" {
    packageManager = {
      type = "homebrew";
      extraPkg = {
        homebrew.brews = [ "watch" ];
        nix.packages = [ "hello" ];
      };
    };
  };
  arch = make "arch" {
    packageManager = {
      type = "pacman";
      extraPkg = {
        pacman = {
          packages = [ "lsof" ];
          aur = [ "example-git" ];
        };
        nix.packages = [ "hello" ];
      };
    };
  };
  forced = make "darwin" {
    requirements.vim = { };
    providerOverrides.vim = "nix";
  };
  nativeExtra = make "darwin" {
    packageManager = {
      type = "nix";
      extraPkg.homebrew.brews = [ "watch" ];
    };
  };
  rejected = args: !(builtins.tryEval (builtins.deepSeq (make "darwin" args).report true)).success;
in
assert mac.installations.homebrew.brews == [ "watch" ];
assert map lib.getName mac.installations.nix.homePackages == [ "hello" ];
assert builtins.elem "lsof" arch.installations.pacman.packages;
assert arch.installations.pacman.aur == [ "example-git" ];
assert map lib.getName arch.installations.nix.homePackages == [ "hello" ];
assert
  forced.resolved.vim.provider == "nix" && forced.resolved.vim.reason == "explicit provider override";
assert nativeExtra.installations.homebrew.brews == [ "watch" ];
assert builtins.elem "/opt/homebrew/bin" nativeExtra.binPaths;
assert builtins.elem "/opt/homebrew/bin" nativeExtra.managerBinPaths;
assert rejected { providerOverrides.vim = "apt"; };
assert rejected {
  packageManager = {
    type = "homebrew";
    extraPkg.pacman.packages = [ "hello" ];
  };
};
assert rejected {
  requirements.vim = { };
  providerOverrides.vim = "homebrew";
  packageOverrides.vim = inputs.nixpkgs.legacyPackages.aarch64-darwin.vim;
};
{
  mixedHomebrewAndNix = true;
  mixedPacmanAurAndNix = true;
  nativeExtrasWithNixDefault = true;
  explicitProviderOverride = true;
  invalidSelectionsRejected = true;
}
