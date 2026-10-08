{ profile, ... }:
{
  platform = "darwin";
  packageManager = {
    type = "homebrew";
    extraPkg.homebrew.brews = [
      "pinentry"
      "watch"
    ];
  };
  system = "aarch64-darwin";
  stateVersion = {
    home = "26.05";
    system = 6;
  };
  features = profile.graphical // {
    coteditor.enable = true;
    iina.enable = true;
    edge.enable = true;
    desktop.macos = {
      enable = true;
      settings = {
        NSGlobalDomain.AppleShowAllExtensions = true;
        finder = {
          ShowPathbar = true;
          ShowStatusBar = true;
          FXPreferredViewStyle = "Nlsv";
          _FXSortFoldersFirst = true;
          FXDefaultSearchScope = "SCcf";
          NewWindowTarget = "Home";
        };
        dock.show-recents = false;
      };
    };
  };
}
