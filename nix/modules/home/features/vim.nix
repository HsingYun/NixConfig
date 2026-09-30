{
  lib,
  pkgs,
  software,
  ...
}:
let
  usesNixPackage = software.vim.provider == "nix";
  # These two existing plugins are not packaged in the pinned nixpkgs.
  # Keep their sources immutable, just like the nixpkgs plugin set.
  cSupport = pkgs.vimUtils.buildVimPlugin {
    pname = "c-support";
    version = "unstable-69f0368";
    src = pkgs.fetchFromGitHub {
      owner = "vim-scripts";
      repo = "c.vim";
      rev = "69f0368c7d8dac196bd94ddfa80d98b1cedc7eb0";
      hash = "sha256-hLKKed7gS6qr3wD2j/nca4kgQfLEfkJgAl0A9mwGgzo=";
    };
  };
  ctrlSF = pkgs.vimUtils.buildVimPlugin {
    pname = "ctrlsf";
    version = "unstable-39db9af";
    src = pkgs.fetchFromGitHub {
      owner = "dyng";
      repo = "ctrlsf.vim";
      rev = "39db9af4d26a91a8a6261c66ffb624f8b3d29114";
      hash = "sha256-IYD/Ume7knN5IvMdSc8dxCeaCEFRCBBI2A4hT5QTTwY=";
    };
  };
  plugins = with pkgs.vimPlugins; [
    a-vim
    cSupport
    tagbar
    nerdtree
    syntastic
    ctrlp-vim
    ctrlSF
    vim-airline
    indentLine
    DoxygenToolkit-vim
    nerdcommenter
    vim-json
    neocomplete-vim
    neoformat
  ];
  customRC = ''
    let g:tagbar_ctags_bin = '${lib.replaceStrings [ "'" ] [ "''" ] (software.ctags.command "ctags")}'
  ''
  + builtins.readFile ../../../assets/vimrc;
in
{
  software = {
    requirements = {
      vim.scopes = [ ];
      ctags = { };
    };
  };
  # The official module owns the Nix wrapper and its plugin closure. Native
  # Vim has no HM package=null interface, so use nixpkgs' vimrc generator.
  programs.vim = lib.mkIf usesNixPackage {
    enable = lib.mkDefault true;

    inherit plugins;
    extraConfig = lib.mkDefault customRC;
  };
  home.file.".vimrc" = lib.mkIf (!usesNixPackage) {
    source = lib.mkDefault (
      pkgs.vimUtils.vimrcFile {
        # Match the official HM module's default plugin as well.
        packages.home-manager.start = [ pkgs.vimPlugins.vim-sensible ] ++ plugins;
        inherit customRC;
      }
    );
  };
}
