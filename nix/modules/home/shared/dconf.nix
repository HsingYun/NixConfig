{ lib, pkgs, ... }:
{
  # Supplement the upstream lifecycle without overriding dconfSettings or
  # maintaining another manifest. This hook also runs when dconf is disabled.
  home.activation.dconfRemovedDatabases = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    # Different manifests can address the same database (settings and
    # databases.user). Upstream must apply the new values after our cleanup.
    lib.hm.dag.entryBetween [ "dconfSettings" ] [ "installPackages" ] ''
      run ${
        import ../../../assets/helpers/common/dconf-removed-databases.nix { inherit pkgs; }
      }/bin/dconf-removed-databases "''${oldGenPath:-}" "$newGenPath"
    ''
  );
}
