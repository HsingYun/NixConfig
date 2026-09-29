{ lib, ... }:

{
  home.file.".vimrc".source = lib.mkDefault ../../../assets/vimrc;
}
