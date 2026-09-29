{ ... }:

{
  # nix-darwin uses an integer state version, independent of NixOS releases.
  system.stateVersion = 6;

  homebrew = {
    enable = true;
    casks = [
      "ghostty"
      "iina"
      "font-maple-mono"
      "font-maple-mono-nf-cn"
    ];
    onActivation = {
      cleanup = "none";
      autoUpdate = false;
      upgrade = false;
    };
  };

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
