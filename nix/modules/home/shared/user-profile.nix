{
  lib,
  pkgs,
  user,
  ...
}:

{
  home.file.".face" = lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && (user.avatar or null) != null) {
    source = user.avatar;
  };
}
