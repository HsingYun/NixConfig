{ lib, ... }:

{
  software.requirements.vim = { };
  home.file.".vimrc".source = lib.mkDefault ../../../assets/vimrc;
}
