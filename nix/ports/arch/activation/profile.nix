{
  config,
  lib,
  pkgs,
  ...
}:
let
  profile = pkgs.buildEnv {
    name = "nixconfig-system";
    paths = config.environment.systemPackages;
    pathsToLink = [
      "/bin"
      "/sbin"
      "/share"
    ];
  };
in
{
  options.native.profileDirectory = lib.mkOption {
    type = lib.types.str;
    default = "/nix/var/nix/profiles/nixconfig-system";
    internal = true;
  };
  config.native.activation.systemProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run /usr/bin/sudo ${pkgs.nix}/bin/nix-env --profile ${lib.escapeShellArg config.native.profileDirectory} --set ${profile}
  '';
}
