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
  native.activation.systemProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run /usr/bin/sudo ${pkgs.nix}/bin/nix-env --profile /nix/var/nix/profiles/nixconfig-system --set ${profile}
  '';
}
