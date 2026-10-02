{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (import ../fixtures/mk-host.nix { inherit inputs; }) mkHost;
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  make =
    manager: provider: extra:
    (mkHost "KeyringProvider" {
      platform = "arch";
      packageManager = manager;
      features = allOff // {
        keyring = true;
      };
      homeConfig = {
        imports = [ extra ];
        home.stateVersion = "26.05";
        software.providerOverrides.gnome-keyring = provider;
      };
    }).views.home;
  verify =
    { manager, provider }:
    let
      h = make manager provider { };
    in
    assert lib.all (a: a.assertion) h.assertions;
    assert h.software.resolved.gnome-keyring.provider == provider;
    assert h.services.gnome-keyring.enable == (provider == "nix");
    assert !(h.software.packageOverrides ? gnome-keyring);
    assert (h.xdg.configFile ? "systemd/user/gnome-keyring-daemon.socket") == (provider == "pacman");
    assert
      provider != "nix"
      || !(lib.hasInfix "/run/wrappers/bin" h.software.resolved.gnome-keyring.package.postFixup);
    "${manager}-${provider}";
  custom = make "pacman" "nix" (
    { pkgs, ... }: {
      software.packageOverrides.gnome-keyring =
        (pkgs.gnome-keyring.override { useWrappedDaemon = false; }).overrideAttrs
          { pname = "custom-keyring"; };
    }
  );
  extra =
    (mkHost "KeyringExtra" {
      platform = "arch";
      packageManager = {
        type = "nix";
        extraPkg.nix.packages = [ "gnome-keyring" ];
      };
      features = allOff // {
        keyring = true;
      };
      homeConfig.home.stateVersion = "26.05";
    }).views.home;
in
assert lib.all (a: a.assertion) extra.assertions;
assert lib.count (p: lib.getName p == "gnome-keyring") extra.home.packages == 1;
assert lib.all (a: a.assertion) custom.assertions;
assert lib.getName custom.software.resolved.gnome-keyring.package == "custom-keyring";
map verify (
  lib.cartesianProduct {
    manager = [
      "nix"
      "pacman"
    ];
    provider = [
      "nix"
      "pacman"
    ];
  }
)
