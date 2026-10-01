{
  config,
  lib,
  pkgs,
  user,
  ...
}:
let
  policy = if config.programs.chromium.enable then config.programs.chromium.extraOpts else { };
  source = pkgs.writeText "chrome-policy.json" (builtins.toJSON policy);
  destination = "/etc/opt/chrome/policies/managed/nixconfig-extensions.json";
in
{
  native.resources.chromePolicy = {
    desired = {
      inherit destination;
      source = if policy == { } then null else toString source;
    };
    check = lib.mkIf (
      policy != { }
    ) "${pkgs.diffutils}/bin/cmp ${source} ${lib.escapeShellArg destination}";
  };
  # Remains imported when Chrome is disabled so owned policy can be removed.
  native.activation.installChromePolicy =
    lib.hm.dag.entryAfter [ "installNativePackages" "writeBoundary" ]
      (
        import ../../../assets/helpers/common/owned-root-file.nix { inherit lib pkgs; } {
          owner = user.username;
          active = policy != { };
          inherit source destination;
        }
      );
}
