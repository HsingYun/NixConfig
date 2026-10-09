{ pkgs }:
let
  inherit (pkgs) lib;
  setSession = pkgs.writeShellScript "set-session-stub" ''
    test "$#" = 1
    printf '%s\n' "$1" "$XDG_DATA_DIRS" > "$PWD/called"
  '';
  make =
    session:
    import ../../../assets/helpers/arch/gdm-session.nix { inherit lib pkgs; } {
      inherit session setSession;
      dataDirs = [ "native data" ];
    };
  niri = make "niri";
  custom = make "custom-session";
in
pkgs.runCommand "gdm-session-check" { } ''
  mkdir -p 'native data/wayland-sessions' 'native data/xsessions'
  # Missing sessions fail before invoking the upstream utility.
  if ${niri} --check; then exit 1; fi
  if ${niri}; then exit 1; fi
  test ! -e called
  touch 'native data/wayland-sessions/niri.desktop'
  ${niri} --check
  test ! -e called
  ${niri}
  printf 'niri\nnative data\n' > expected
  diff -u expected called
  rm called
  touch 'native data/xsessions/custom-session.desktop'
  ${custom}
  printf 'custom-session\nnative data\n' > expected
  diff -u expected called
  touch "$out"
''
