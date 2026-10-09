{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  cases = import ../software/host-cases.nix { inherit inputs; };
  prefix = [
    "/test/root-command"
    "--label=two words"
  ];
  cfg =
    (cases.mkHost "PrivilegeTest" {
      platform = "arch";
      features = cases.allOff // {
        niri = true;
        noctalia = true;
        smartcard = true;
        chrome = true;
      };
      homeConfig.home.stateVersion = "26.05";
      systemConfig = { lib, pkgs, ... }: {
        native = {
          privilegeCommand = lib.mkForce prefix;
          userCommand = lib.mkForce (user: [
            "/test/user-command"
            "--as"
            user
          ]);
        };
        security.polkit.extraConfig = "// Test policy";
        services.displayManager.noctalia-greeter.settings.test = true;
        software = {
          packageOverrides.htop = pkgs.htop;
          migration.removeReplaced = [ "htop" ];
        };
      };
    }).views.system;
  rootStages = [
    "systemProfile"
    "nativeSystemd"
    "installNativePackages"
    "removeReplacedNativePackages"
    "installChromePolicy"
    "nativeSmartcard"
    "selectNativeLoginManager"
  ];
in
assert lib.all (a: a.assertion) cfg.assertions;
assert lib.all (
  name:
  lib.hasInfix (lib.escapeShellArgs prefix) cfg.native.activation.${name}.data
  && !(lib.hasInfix "/usr/bin/sudo" cfg.native.activation.${name}.data)
) rootStages;
assert lib.hasInfix "/test/user-command" cfg.native.activation.checkNativeGreeter.data;
assert !(lib.hasInfix "/usr/bin/sudo" cfg.native.activation.checkNativeGreeter.data);
assert lib.hasInfix (lib.escapeShellArgs prefix) cfg.native.resources.smartcardPolicy.check;
{
  allRootEffectsUseThePortCommand = true;
  userExecutionHasASeparatePortCommand = true;
  protectedVerificationUsesTheSameRootCommand = true;
}
