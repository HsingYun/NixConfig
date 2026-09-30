{ lib, ... }:

{
  xdg = {
    enable = lib.mkDefault true;
    localBinInPath = lib.mkDefault true;
    userDirs.enable = lib.mkDefault true;
  };
}
