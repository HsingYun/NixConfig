{
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./shared/user-profile.nix
    ../shared/features.nix
    ./shared/autostart.nix
    ./shared/keyring.nix
    ./shared/dconf.nix
    ./shared/launcher.nix
    ./policies/applications.nix
    ./integrations/applications.nix
    ./software
  ];

  software.requirements =
    let
      profiles = import ../../lib/software/profile-requirements.nix { inherit pkgs; };
    in
    lib.genAttrs (builtins.attrNames profiles.user) (_: { })
    // lib.genAttrs (builtins.attrNames profiles.base) (_: {
      scopes = [ "system" ];
    });
  programs.home-manager.enable = true;
}
