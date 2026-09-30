{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./shared/user-profile.nix
    ./shared/features.nix
    ./shared/keyring.nix
    ./shared/dconf.nix
    ./shared/chrome.nix
    ./shared/launcher.nix
    ./software
  ];

  software.requirements =
    let
      profiles = import ../../lib/software/profiles.nix { inherit pkgs; };
      platform = config.software.platform;
    in
    lib.genAttrs (builtins.attrNames profiles.user) (_: { })
    // lib.genAttrs (builtins.attrNames profiles.base) (_: {
      scopes = [ "system" ];
    });
  programs.home-manager.enable = true;
}
