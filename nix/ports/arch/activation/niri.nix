{
  config,
  helpers,
  lib,
  user,
  ...
}:
let
  home = config.home-manager.users.${user.username};
  file = helpers.managedHomeFile { inherit lib; } {
    inherit home;
    name = "${home.xdg.configHome}/niri/config.kdl";
  };
  active = home.wayland.windowManager.niri.enable && file.enable;
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
        inherit (file) target;
      };
      check = validate file.target;
    };
  };
}
