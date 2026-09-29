{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./shared/user-profile.nix
    ./software
  ];

  software.requirements =
    let
      profiles = import ../../lib/software/profiles.nix { inherit pkgs; };
      platform = config.software.platform;
    in
    lib.genAttrs (builtins.attrNames profiles.user) (_: { })
    // lib.genAttrs (builtins.attrNames profiles.base) (_: {
      scopes = [ (if platform == "linux" then "home" else "system") ];
    });
  programs.home-manager.enable = true;
}
