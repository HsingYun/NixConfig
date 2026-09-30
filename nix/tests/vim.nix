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
    manager:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = vimPkgs;
      modules = [
        ../modules/home/software
        ../modules/home/features/vim.nix
        {
          home.username = "test";
          home.homeDirectory = if darwin then "/Users/test" else "/home/test";
          home.stateVersion = "26.05";
          software.platform = if darwin then "darwin" else "arch";
          software.packageManager = manager;
        }
      ];
    };
  nix = (make "nix").config;
  native = (make (if darwin then "homebrew" else "pacman")).config;
  script = pkgs.writeText "vim-regression.vim" ''
    call assert_equal(2, exists(':NERDTreeToggle'))
    call assert_equal(2, exists(':CtrlSF'))
    call assert_equal(2, exists(':TagbarToggle'))
    call assert_equal(0, exists(':PlugInstall'))
    call assert_equal([], glob($HOME . '/.vim/plugged', 0, 1))
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
assert native.software.resolved.vim.provider == (if darwin then "homebrew" else "pacman");
assert toString nix.software.resolved.vim.runtimePackage == toString nix.programs.vim.package;
pkgs.runCommand "vim-regression" { } ''
  export HOME="$PWD/nix-home"
  mkdir "$HOME"
  ${nix.programs.vim.package}/bin/vim -n -i NONE -es -S ${script} || {
    cat "$HOME/errors" 2>/dev/null || true
    exit 1
  }
  export HOME="$PWD/native-home"
  mkdir "$HOME"
  # An unwrapped Vim exercises the file consumed by pacman/Homebrew Vim.
  ${pkgs.vim}/bin/vim -u ${native.home.file.".vimrc".source} -n -i NONE -es -S ${script} || {
    cat "$HOME/errors" 2>/dev/null || true
    exit 1
  }
  touch "$out"
''
