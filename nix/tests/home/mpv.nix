{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  darwin = pkgs.stdenv.hostPlatform.isDarwin;
  script =
    (pkgs.runCommand "mpv-script-fixture" { } ''
      mkdir -p "$out/share/mpv/scripts/data"
      echo '-- client fixture' > "$out/share/mpv/scripts/client.lua"
      echo '-- server fixture' > "$out/share/mpv/scripts/server.lua"
      echo 'sibling resource' > "$out/share/mpv/scripts/data/resource.txt"
    '')
    // {
      scriptName = "client.lua";
      extraScriptsToLoad = [ "server.lua" ];
    };
  sameName = (pkgs.writeTextDir "share/mpv/scripts/client.lua" "-- another script\n") // {
    scriptName = "client.lua";
  };
  modernx = pkgs.mpvScripts.modernx;
  thumbfast = pkgs.mpvScripts.thumbfast;
  make =
    scripts:
    (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = { inherit inputs; };
      modules = [
        ../../modules/home/software
        ../../ports/common/home/capabilities/mpv.nix
        {
          home = {
            username = "test";
            homeDirectory = if darwin then "/Users/test" else "/home/test";
            stateVersion = "26.05";
          };
          software = {
            platform = if darwin then "darwin" else "arch";
            packageManager = if darwin then "homebrew" else "pacman";
          };
          programs.mpv = {
            enable = true;
            inherit scripts;
            config.hwdec = "auto";
          };
        }
      ];
    }).config;
  native = make [
    script
    sameName
    modernx
    thumbfast
  ];
  empty = make [ ];
in
assert lib.all (a: a.assertion) (native.assertions ++ empty.assertions);
assert native.programs.mpv.package == null && native.programs.mpv.finalPackage == null;
assert !(empty.programs.mpv.config ? script);
assert !(empty.xdg.configFile ? "mpv/fonts");
assert !(empty.programs.mpv.scriptOpts ? thumbfast);
assert !(native.programs.mpv.config ? script);
pkgs.runCommand "mpv-native-files" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  python3 - ${native.home-files}/.config/mpv ${lib.escapeShellArgs modernx.fontDirectories} <<'PY'
  from pathlib import Path
  import sys
  config = Path(sys.argv[1])
  expected_fonts = {p.resolve() for directory in sys.argv[2:] for p in Path(directory).rglob('*') if p.is_file()}
  exposed_fonts = {p.resolve() for p in (config / 'fonts').iterdir()}
  assert expected_fonts and expected_fonts == exposed_fonts
  text = (config / 'mpv.conf').read_text()
  for path in [
      '${script}/share/mpv/scripts/client.lua',
      '${script}/share/mpv/scripts/server.lua',
      '${sameName}/share/mpv/scripts/client.lua',
      '${modernx}/share/mpv/scripts/modernx.lua',
      '${thumbfast}/share/mpv/scripts/thumbfast.lua',
  ]:
      assert Path(path).is_file(), path
      assert 'script=%' + str(len(path)) + '%' + path in text, path
  assert Path('${script}/share/mpv/scripts/data/resource.txt').read_text().strip() == 'sibling resource'
  PY
  grep -Fx 'mpv_path=${native.software.resolved.mpv.command "mpv"}' ${native.home-files}/.config/mpv/script-opts/thumbfast.conf
  grep -F 'hwdec=' ${native.home-files}/.config/mpv/mpv.conf
  test ! -e ${empty.home-files}/.config/mpv/fonts
  test ! -e ${empty.home-files}/.config/mpv/script-opts/thumbfast.conf
  touch "$out"
''
