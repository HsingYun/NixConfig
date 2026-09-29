{
  platform = "nixos";
  packageManager = {
    type = "nix";
    externalPkg.packages = [
      "aria2"
      "gnupg"
      "gnutls"
      "graphviz"
      "ncurses"
      "openssl"
      "pinentry-curses"
      "rsync"
      "sqlite"
      "procps"
      "xz"
      "zlib"
      "zstd"
    ];
  };
  system = "x86_64-linux";
  features = {
    efiTools = true;
    chrome = true;
    vscode = true;
    codex = true;
    screenRotate = true;
    devel = true;
    chinese = true;
    gnome = true;
    ghostty = true;
    mpv = true;
  };
  hardwareConfig = ./hardware.nix;
  systemConfig = ./system.nix;
  homeConfig = ./home.nix;
}
