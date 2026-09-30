{
  lib,
  pkgs,
  software,
  ...
}:
{
  config = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    software = {
      requirements.xdg-terminal-exec.installNix = false;
      bindings.xdg-terminal-exec = {
        enableOption = [
          "xdg"
          "terminal-exec"
          "enable"
        ];
        packageOption = [
          "xdg"
          "terminal-exec"
          "package"
        ];
      };
    };
    xdg.terminal-exec.package = lib.mkDefault software.xdg-terminal-exec.package;
  };
}
