{ config, lib, ... }:

{
  # nix-darwin uses an integer state version, independent of NixOS releases.
  system.stateVersion = 6;

  homebrew = {
    enable = true;
    brews = [
      "abseil"
      "aria2"
      "clang-format"
      "coreutils"
      "curl"
      "fastfetch"
      "gcc"
      "gdb"
      "git"
      "git-lfs"
      "gnupg"
      "gnutls"
      "go"
      "graphviz"
      "htop"
      "llvm"
      "ncurses"
      "ninja"
      "node"
      "openjdk"
      "openssl@4"
      "pinentry"
      "pinentry-mac"
      "protobuf"
      "python@3.14"
      "ripgrep"
      "rsync"
      "rust"
      "sqlite"
      "telnet"
      "tree"
      "typescript"
      "vim"
      "watch"
      "wget"
      "xz"
      "zlib"
      "zstd"
    ];
    casks = [
      "coteditor"
      "ghostty"
      "google-chrome"
      "iina"
      "font-maple-mono"
      "font-maple-mono-nf-cn"
      "microsoft-edge"
    ];
    onActivation = {
      cleanup = "none";
      autoUpdate = false;
      upgrade = false;
    };
  };

  # Prefer Homebrew's Vim over the copy bundled with macOS.
  environment.systemPath = lib.mkBefore [ "${config.homebrew.prefix}/opt/vim/bin" ];

  system.defaults = {
    NSGlobalDomain.AppleShowAllExtensions = true;
    finder = {
      ShowPathbar = true;
      ShowStatusBar = true;
      FXPreferredViewStyle = "Nlsv";
      _FXSortFoldersFirst = true;
      FXDefaultSearchScope = "SCcf";
      NewWindowTarget = "Home";
    };
    dock = {
      tilesize = 64;
      magnification = false;
      show-recents = false;
      wvous-br-corner = 14;
    };
  };
}
