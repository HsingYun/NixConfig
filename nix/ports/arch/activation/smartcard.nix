{
  config,
  lib,
  pkgs,
  user,
  ...
}:
let
  active = config.security.polkit.enable && config.security.polkit.extraConfig != "";
  source = pkgs.writeText "smartcard-polkit.rules" config.security.polkit.extraConfig;
  destination = "/etc/polkit-1/rules.d/60-nixconfig-smartcard-${user.username}.rules";
in
{
  native.resources.smartcardPolicy = {
    desired = {
      inherit destination;
      source = if active then toString source else null;
    };
    check = lib.mkIf active "${lib.escapeShellArgs config.native.privilegeCommand} ${pkgs.diffutils}/bin/cmp ${source} ${lib.escapeShellArg destination}";
  };
  native.activation.nativeSmartcard =
    lib.hm.dag.entryBetween [ "nativeSystemd" ] [ "installNativePackages" "linkGeneration" ]
      (
        import ../../../assets/helpers/common/owned-root-file.nix { inherit lib pkgs; } {
          inherit (config.native) privilegeCommand;
          owner = user.username;
          inherit active source destination;
        }
      );
}
