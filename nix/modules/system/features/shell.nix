{
  lib,
  pkgs,
  user,
  ...
}:

{
  programs.zsh.enable = lib.mkDefault true;
  users.users.${user.username} = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    useDefaultShell = false;
    shell = lib.mkDefault pkgs.zsh;
  };
}
