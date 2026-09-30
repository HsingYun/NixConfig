{ pkgs }:
let
  inherit (pkgs) lib;
  inherit (import ./recipes.nix { inherit pkgs; }) nix brew pacman;
  base = {
    nano = {
      nix = nix pkgs.nano;
      homebrew = brew "nano";
      pacman = pacman "nano";
    };
    wget = {
      nix = nix pkgs.wget;
      homebrew = brew "wget";
      pacman = pacman "wget";
    };
    curl = {
      nix = nix pkgs.curl;
      homebrew = brew "curl";
      pacman = pacman "curl";
    };
  };
  user = {
    fastfetch = {
      nix = nix pkgs.fastfetch;
      homebrew = brew "fastfetch";
      pacman = pacman "fastfetch";
    };
    jq = {
      nix = nix pkgs.jq;
      homebrew = brew "jq";
      pacman = pacman "jq";
    };
    ripgrep = {
      nix = nix pkgs.ripgrep;
      homebrew = brew "ripgrep";
      pacman = pacman "ripgrep";
    };
    fd = {
      nix = nix pkgs.fd;
      homebrew = brew "fd";
      pacman = pacman "fd";
    };
    tree = {
      nix = nix pkgs.tree;
      homebrew = brew "tree";
      pacman = pacman "tree";
    };
    htop = {
      nix = nix pkgs.htop;
      homebrew = brew "htop";
      pacman = pacman "htop";
    };
  };
in
{
  inherit base user;
  commonTools =
    lib.genAttrs
      [
        "aria2"
        "gnutls"
        "graphviz"
        "ncurses"
        "openssl"
        "rsync"
        "sqlite"
        "xz"
        "zlib"
        "zstd"
      ]
      (name: {
        # The generic terminfo database is a fallback: terminal packages ship
        # definitions matching their own versions (notably Ghostty).
        nix = nix (if name == "ncurses" then lib.lowPrio pkgs.${name} else pkgs.${name});
        homebrew = brew (if name == "openssl" then "openssl@4" else name);
        pacman = pacman name;
      });
  devel = {
    inherit (base) curl wget;
    inherit (user)
      ripgrep
      fd
      jq
      tree
      ;
    git = {
      nix = nix pkgs.git;
      homebrew = brew "git";
      pacman = pacman "git";
    };
    coreutils = {
      nix = nix pkgs.coreutils;
      homebrew = brew "coreutils" // {
        binDirs = [
          "libexec/gnubin"
          "bin"
        ];
        commandDir = "libexec/gnubin";
      };
      pacman = pacman "coreutils";
    };
    abseil-cpp = {
      nix = nix pkgs.abseil-cpp;
      homebrew = brew "abseil";
      pacman = pacman "abseil-cpp";
    };
    gcc = {
      # Both compiler wrappers provide cc/c++; keep Clang as the Nix default.
      nix = nix (pkgs.lib.setPrio 20 pkgs.gcc);
      homebrew = brew "gcc";
      pacman = pacman "gcc";
    };
    gdb = {
      nix = nix pkgs.gdb;
      homebrew = brew "gdb";
      pacman = pacman "gdb";
    };
    git-lfs = {
      nix = nix pkgs.git-lfs;
      homebrew = brew "git-lfs";
      pacman = pacman "git-lfs";
    };
    go = {
      nix = nix pkgs.go;
      homebrew = brew "go";
      pacman = pacman "go";
    };
    nodejs = {
      nix = nix pkgs.nodejs;
      homebrew = brew "node";
      pacman = pacman "nodejs";
    };
    openjdk = {
      nix = nix pkgs.jdk;
      homebrew = brew "openjdk";
      pacman = pacman "jdk-openjdk";
    };
    protobuf = {
      nix = nix pkgs.protobuf;
      homebrew = brew "protobuf";
      pacman = pacman "protobuf";
    };
    rust = {
      nix = nix pkgs.rustc;
      homebrew = brew "rust";
      pacman = pacman "rust";
    };
    cargo = {
      nix = nix pkgs.cargo;
      homebrew = brew "rust";
      pacman = pacman "rust";
    };
    typescript = {
      nix = nix pkgs.typescript;
      homebrew = brew "typescript";
      pacman = pacman "typescript";
    };
    telnet = {
      nix = nix pkgs.inetutils;
      homebrew = brew "telnet";
      pacman = pacman "inetutils";
    };
    clang = {
      nix = nix pkgs.llvmPackages.clang;
      homebrew = brew "llvm";
      pacman = pacman "clang";
    };
    clang-tools = {
      nix = nix pkgs.llvmPackages.clang-tools;
      homebrew = brew "llvm";
      pacman = pacman "clang";
    };
    llvm = {
      nix = nix pkgs.llvmPackages.llvm // {
        outputs = [
          "out"
          "dev"
        ];
      };
      homebrew = brew "llvm";
      pacman = pacman "llvm";
    };
    lld = {
      nix = nix pkgs.llvmPackages.lld;
      homebrew = brew "lld";
      pacman = pacman "lld";
    };
    lldb = {
      nix = nix pkgs.llvmPackages.lldb;
      homebrew = brew "llvm";
      pacman = pacman "lldb";
    };
    cmake = {
      nix = nix pkgs.cmake;
      homebrew = brew "cmake";
      pacman = pacman "cmake";
    };
    ninja = {
      nix = nix pkgs.ninja;
      homebrew = brew "ninja";
      pacman = pacman "ninja";
    };
    meson = {
      nix = nix pkgs.meson;
      homebrew = brew "meson";
      pacman = pacman "meson";
    };
    make = {
      nix = nix pkgs.gnumake;
      homebrew = brew "make" // {
        binDirs = [
          "libexec/gnubin"
          "bin"
        ];
        commandDir = "libexec/gnubin";
      };
      pacman = pacman "make";
    };
    autoconf = {
      nix = nix pkgs.autoconf;
      homebrew = brew "autoconf";
      pacman = pacman "autoconf";
    };
    automake = {
      nix = nix pkgs.automake;
      homebrew = brew "automake";
      pacman = pacman "automake";
    };
    libtool = {
      nix = nix pkgs.libtool;
      homebrew = brew "libtool" // {
        binDirs = [
          "libexec/gnubin"
          "bin"
        ];
        commandDir = "libexec/gnubin";
      };
      pacman = pacman "libtool";
    };
    m4 = {
      nix = nix pkgs.gnum4;
      homebrew = brew "m4";
      pacman = pacman "m4";
    };
    pkg-config = {
      nix = nix pkgs.pkg-config;
      homebrew = brew "pkgconf";
      pacman = pacman "pkgconf";
    };
    file = {
      nix = nix pkgs.file;
      homebrew = brew "file";
      pacman = pacman "file";
    };
    patch = {
      nix = nix pkgs.patch;
      homebrew = brew "gpatch" // {
        binDirs = [
          "libexec/gnubin"
          "bin"
        ];
        commandDir = "libexec/gnubin";
      };
      pacman = pacman "patch";
    };
    diffutils = {
      nix = nix pkgs.diffutils;
      homebrew = brew "diffutils";
      pacman = pacman "diffutils";
    };
    python = {
      nix = nix pkgs.python3;
      homebrew = brew "python@3.14" // {
        binDirs = [
          "libexec/bin"
          "bin"
        ];
      };
      pacman = pacman "python";
    };
  };
}
