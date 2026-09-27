{ pkgs, ... }:

{
  home.packages = with pkgs; [
    git
    ripgrep
    fd
    jq
    tree
    curl
    wget

    llvmPackages.clang
    llvmPackages.clang-tools
    llvmPackages.llvm
    llvmPackages.llvm.dev
    llvmPackages.lld
    llvmPackages.lldb

    cmake
    ninja
    meson
    gnumake
    autoconf
    automake
    libtool
    gnum4
    pkg-config

    file
    patch
    diffutils
    python3
  ];
}
