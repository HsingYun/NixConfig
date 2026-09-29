{
  config,
  lib,
  pkgs,
  user,
  software,
  ...
}:

{
  programs.zsh = {
    enable = lib.mkDefault true;
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    package = lib.mkDefault software.zsh.package;
  };
  assertions = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    {
      assertion =
        !config.programs.zsh.enable
        || toString config.programs.zsh.package == toString software.zsh.package;
      message = "Software: programs.zsh.package bypasses the selected package. Use software.packageOverrides.zsh in the user's Home Manager configuration.";
    }
  ];
  users.users.${user.username} = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    useDefaultShell = false;
    shell = lib.mkDefault software.zsh.package;
  };
}
