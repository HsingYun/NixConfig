{
  config,
  lib,
  user,
  ...
}:
let
  home = config.home-manager.users.${user.username};
  file = home.xdg.configFile."niri/config.kdl" or null;
  active = home.wayland.windowManager.niri.enable && file != null && file.enable;
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
          run ${validate (toString file.source)}
        '';
    native.resources.niri-config = {
      desired = {
        source = toString file.source;
        target = destination;
      };
      check = validate destination;
    };
  };
}
