{ pkgs }:
let
  python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
  legacy = pkgs.writeText "hm-dconf.ini" ''
    [nixconfig-tests]
    managed="legacy"
    edited=true
  '';
in
pkgs.runCommand "dconf-lifecycle-check" { } ''
  export HOME="$TMPDIR/home" XDG_CONFIG_HOME="$TMPDIR/home/.config" PYTHONDONTWRITEBYTECODE=1
  mkdir -p "$XDG_CONFIG_HOME"
  export XDG_DATA_DIRS=${pkgs.dconf}/share
  export GI_TYPELIB_PATH=${pkgs.glib.out}/lib/girepository-1.0
  ${pkgs.dbus}/bin/dbus-run-session --dbus-daemon=${pkgs.dbus}/bin/dbus-daemon --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- ${python}/bin/python3 ${./dconf.py} ${../assets/helpers}/dconf.py ${pkgs.dconf}/bin/dconf ${legacy}
  touch "$out"
''
