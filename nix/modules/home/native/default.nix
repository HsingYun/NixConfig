{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  backend = pkgs.writeShellScriptBin "nixconfig-system" ''
    exec ${pkgs.python3}/bin/python3 ${../../../assets/helpers}/common/system-backend.py \
      --plan ${osConfig.native.plan} \
      --state ${lib.escapeShellArg "${config.xdg.stateHome}/nixconfig/system"} "$@"
  '';
  command = "${backend}/bin/nixconfig-system";
  wrap =
    name: step:
    step
    // {
      after = lib.unique (step.after ++ [ "nativeSystemBegin" ]);
      data = import ../../../assets/helpers/common/system-stage.nix { inherit lib; } {
        inherit command name;
        script = step.data;
      };
    };
in
{
  imports = [ ./systemd.nix ];
  home.packages = [ backend ];
  home.sessionPath = [ "${osConfig.native.profileDirectory}/bin" ];
  home.activation =
    lib.mapAttrs (
      _: step: step // { before = lib.unique (step.before ++ [ "writeBoundary" ]); }
    ) osConfig.native.preflight
    // lib.mapAttrs wrap osConfig.native.activation
    // {
      nativeSystemBegin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${command} begin --pid "$$"
      '';
      # Success includes HM linking, user-service activation and port checks.
      # A failure between native stages leaves an incomplete attempt, never a
      # successful one. Status identifies an exited activation as interrupted.
      nativeSystemComplete =
        lib.hm.dag.entryAfter (lib.remove "nativeSystemComplete" (lib.attrNames config.home.activation))
          (
            import ../../../assets/helpers/common/system-stage.nix { inherit lib; } {
              inherit command;
              name = "verification";
              script = ''
                run ${command} verify
                run ${command} complete --pid "$$"
              '';
              complete = false;
            }
          );
    };
}
