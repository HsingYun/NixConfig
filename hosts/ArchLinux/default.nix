{
  platform = "linux";
  packageManager = {
    type = "pacman";
    externalPkg.packages = [
      "aria2"
      "gnupg"
      "gnutls"
      "graphviz"
      "ncurses"
      "openssl"
      "pinentry"
      "rsync"
      "sqlite"
      "procps-ng"
      "xz"
      "zlib"
      "zstd"
    ];
  };
  system = "x86_64-linux";
  features = {
    chrome = true;
    vscode = true;
    devel = true;
  };
  homeConfig = ./home.nix;
}
