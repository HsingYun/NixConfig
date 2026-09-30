{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  vimPkgs = import inputs.nixpkgs {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfreePredicate =
      package:
      builtins.elem (lib.getName package) [
        "a.vim"
        "DoxygenToolkit.vim"
      ];
  };
  darwin = pkgs.stdenv.hostPlatform.isDarwin;
  # Build the actual feature in an isolated Home Manager configuration; do not
  # activate it or read the invoking user's editor configuration.
  make =
    manager: extra:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = vimPkgs;
      modules = [
        ../modules/home/software
        ../modules/home/features/vim.nix
        extra
        {
          home.username = "test";
          home.homeDirectory = if darwin then "/Users/test" else "/home/test";
          home.stateVersion = "26.05";
          software.platform = if darwin then "darwin" else "arch";
          software.packageManager = manager;
        }
      ];
    };
  manager = if darwin then "homebrew" else "pacman";
  nix = (make "nix" { }).config;
  native = (make manager { }).config;
  # No native binaries are installed in the build sandbox. Keep native Vim
  # configuration, overriding only ctags with its real Nix executable.
  nativeRuntime =
    (make manager {
      software.packageOverrides.ctags = pkgs.universal-ctags;
    }).config;
  script = pkgs.writeText "vim-regression.vim" ''
    " A build sandbox has no desktop clipboard service.
    set clipboard=
    set shell=${pkgs.runtimeShell}
    call assert_equal(2, exists(':NERDTreeToggle'))
    call assert_equal(2, exists(':CtrlSF'))
    call assert_equal(2, exists(':TagbarToggle'))
    call assert_equal(0, exists(':PlugInstall'))
    call assert_equal([], glob($HOME . '/.vim/plugged', 0, 1))
    call writefile(['int review_tagbar_symbol() { return 42; }'], $HOME . '/tags.cpp')
    execute 'edit ' . fnameescape($HOME . '/tags.cpp')
    let savedpath = $PATH
    let $PATH = $HOME . '/missing'
    call assert_true(executable(g:tagbar_ctags_bin))
    call tagbar#currenttag("%s", "")
    call tagbar#ForceUpdate()
    call assert_match('review_tagbar_symbol', tagbar#currenttag("%s", ""))
    let $PATH = savedpath
    call writefile(['original on disk'], $HOME . '/sample.cpp')
    execute 'edit ' . fnameescape($HOME . '/sample.cpp')
    call setline(1, ['unsaved first', 'unsaved second'])
    let original = getline(1, '$')
    let oldpath = $PATH
    let $PATH = $HOME . '/missing'
    try
      call CodeFormat()
      call assert_report('Missing formatter must fail')
    catch /CodeFormat: astyle is not installed/
    endtry
    call assert_equal(original, getline(1, '$'))
    call assert_equal(['original on disk'], readfile($HOME . '/sample.cpp'))
    call mkdir($HOME . '/bin')
    call writefile(['#!${pkgs.runtimeShell}', 'echo formatter-error', 'exit 1'], $HOME . '/bin/astyle')
    call setfperm($HOME . '/bin/astyle', 'rwx------')
    let $PATH = $HOME . '/bin'
    try
      call CodeFormat()
      call assert_report('Failed formatter must fail')
    catch /CodeFormat: astyle failed/
    endtry
    call assert_equal(original, getline(1, '$'))
    call assert_equal(['original on disk'], readfile($HOME . '/sample.cpp'))
    call writefile(['#!${pkgs.runtimeShell}', 'echo formatted'], $HOME . '/bin/astyle')
    call CodeFormat()
    call assert_equal(['formatted'], getline(1, '$'))
    call assert_equal(['original on disk'], readfile($HOME . '/sample.cpp'))
    let $PATH = oldpath
    if !empty(v:errors)
      call writefile(v:errors, $HOME . '/errors')
      cquit
    endif
    qall!
  '';
in
assert lib.all (a: a.assertion) (nix.assertions ++ native.assertions);
assert nix.programs.vim.enable && !(nix.home.file ? ".vimrc");
assert !native.programs.vim.enable && native.home.file ? ".vimrc";
assert native.software.resolved.vim.provider == manager;
assert native.software.resolved.ctags.provider == manager;
assert (
  if darwin then
    builtins.elem "universal-ctags" native.software.plan.installations.homebrew.brews
  else
    builtins.elem "ctags" native.software.plan.installations.pacman.packages
);
assert nix.software.resolved.ctags.provider == "nix";
assert toString nix.software.resolved.vim.runtimePackage == toString nix.programs.vim.package;
pkgs.runCommand "vim-regression" { } ''
  export HOME="$PWD/nix-home"
  mkdir "$HOME"
  ${pkgs.coreutils}/bin/timeout 30 ${nix.programs.vim.package}/bin/vim -n -i NONE -es -V1"$HOME/vim.log" -S ${script} "$HOME/initial.txt" || {
    tail -200 "$HOME/vim.log"
    cat "$HOME/errors" 2>/dev/null || true
    exit 1
  }
  export HOME="$PWD/native-home"
  mkdir "$HOME"
  # An unwrapped Vim exercises the file consumed by pacman/Homebrew Vim.
  ${pkgs.coreutils}/bin/timeout 30 ${pkgs.vim}/bin/vim -u ${
    nativeRuntime.home.file.".vimrc".source
  } -n -i NONE -es -V1"$HOME/vim.log" -S ${script} "$HOME/initial.txt" || {
    tail -200 "$HOME/vim.log"
    cat "$HOME/errors" 2>/dev/null || true
    exit 1
  }
  touch "$out"
''
