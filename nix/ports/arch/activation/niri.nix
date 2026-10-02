{
  config,
  lib,
  user,
  ...
}:
let
  home = config.home-manager.users.${user.username};
  # XDG supplies the declaration's key; home.file owns the final deployment
  # after all enable, target and source overrides have been merged.
  file = home.home.file."${home.xdg.configHome}/niri/config.kdl" or null;
  active = home.wayland.windowManager.niri.enable && file != null && file.enable;
  # Match HM's source snapshot: local paths must remain available after the
  # original file changes or disappears. Keep derivations/out-of-store links.
  source =
    if builtins.hasContext (toString file.source) then
      file.source
    else
      builtins.path {
        path = file.source;
        name = home.lib.strings.storeFileName (baseNameOf (toString file.source));
      };
  destination =
    if lib.hasPrefix "/" file.target then file.target else "${home.home.homeDirectory}/${file.target}";
  validate = path: "/usr/bin/niri validate --config ${lib.escapeShellArg path}";
in
{
  config = lib.mkIf active {
    # Validate the candidate before linking; the existing native verifier checks
    # the deployed file after activation and on subsequent manual verification.
    native.activation.validateNiriConfig =
      lib.hm.dag.entryBetween [ "linkGeneration" ] [ "installNativePackages" ]
        ''
          run ${validate (toString source)}
        '';
    native.resources.niri-config = {
      desired = {
        source = toString source;
        target = destination;
      };
      check = validate destination;
    };
  };
}
