{
  config,
  lib,
  pkgs,
  user,
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
    default = "/nix/var/nix/profiles/nixconfig-system-${user.username}";
    internal = true;
  };
  config.native = {
    resources.profile = {
      desired = {
        path = config.native.profileDirectory;
        source = toString profile;
      };
      check = ''
        test "$(${pkgs.coreutils}/bin/readlink -f ${lib.escapeShellArg config.native.profileDirectory})" = ${profile}
      '';
    };
    activation.systemProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      import ../../../assets/helpers/common/system-profile-activation.nix { inherit lib; } {
        inherit (config.native) privilegeCommand;
        nixEnv = "${pkgs.nix}/bin/nix-env";
        readlink = "${pkgs.coreutils}/bin/readlink";
        profilePath = config.native.profileDirectory;
        packageSet = toString profile;
      }
    );
  };
}
