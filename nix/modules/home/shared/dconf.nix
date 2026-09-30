{ lib, pkgs, ... }:
{
  # Supplement the upstream lifecycle without overriding dconfSettings or
  # maintaining another manifest. This hook also runs when dconf is disabled.
  home.activation.dconfRemovedDatabases = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.hm.dag.entryAfter [ "dconfSettings" "installPackages" ] ''
      run ${
        import ../../../assets/helpers/dconf-removed-databases.nix { inherit pkgs; }
      }/bin/dconf-removed-databases "''${oldGenPath:-}" "$newGenPath"
    ''
  );
}
