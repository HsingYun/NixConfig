{ ... }:

{
  # nix-darwin uses an integer state version, independent of NixOS releases.
  system = {
    stateVersion = 6;
    defaults = {
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

}
