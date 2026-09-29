{
  platform = "darwin";
  packageManager = {
    type = "homebrew";
    externalPkg.brews = [
      "aria2"
      "gnupg"
      "gnutls"
      "graphviz"
      "ncurses"
      "openssl@4"
      "pinentry"
      "pinentry-mac"
      "rsync"
      "sqlite"
      "watch"
      "xz"
      "zlib"
      "zstd"
    ];
  };
  system = "aarch64-darwin";
  features = {
    ghostty = true;
    chrome = true;
    vscode = true;
    coteditor = true;
    iina = true;
    edge = true;
    mapleMono = true;
    devel = true;
  };
  systemConfig = ./system.nix;
  homeConfig = ./home.nix;
}
