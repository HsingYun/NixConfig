{
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    software = {
      requirements.xdg-terminal-exec.scopes = [ ];
    };
  };
}
