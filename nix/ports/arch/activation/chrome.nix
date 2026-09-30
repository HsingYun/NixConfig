{
  config,
  lib,
  pkgs,
  user,
  ...
}:
let
  policy = if config.programs.chromium.enable then config.programs.chromium.extraOpts else { };
in
{
  # Remains imported when Chrome is disabled so owned policy can be removed.
  native.activation.installChromePolicy = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    import ../../../assets/helpers/common/owned-root-file.nix { inherit lib pkgs; } {
      owner = user.username;
      active = policy != { };
      text = builtins.toJSON policy;
      destination = "/etc/opt/chrome/policies/managed/nixconfig-extensions.json";
    }
  );
}
