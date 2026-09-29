{ inputs, pkgs }:

let
  inherit (pkgs) lib;
  profile =
    name: exec:
    pkgs.runCommand name { } ''
      mkdir -p "$out/share/applications"
      cat > "$out/share/applications/vim.desktop" <<'EOF'
      [Desktop Entry]
      Type=Application
      Name=Editor
      Exec=${exec} %F
      Terminal=true
      MimeType=text/plain;
      Categories=Utility;TextEditor;
      EOF
      cp "$out/share/applications/vim.desktop" "$out/share/applications/visible.desktop"
    '';
  userProfile = profile "customized-editor-profile" "user-editor";
  systemProfile = profile "system-editor-profile" "system-editor";
  emptyProfile = pkgs.runCommand "empty-application-profile" { } ''mkdir -p "$out"'';
  home =
    roots: hiddenEntries:
    (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ../modules/home/shared/launcher.nix
        {
          home = {
            username = "test";
            homeDirectory = "/home/test";
            stateVersion = "26.05";
          };
          software.platform = "nixos";
          desktop.launcher = {
            inherit hiddenEntries;
            packageRoots = lib.mkForce roots;
          };
        }
      ];
    }).config;
  filtered = home [ userProfile systemProfile ] [ "vim.desktop" "absent.desktop" ];
  absent = home [ emptyProfile ] [ "vim.desktop" ];
  disabled = home [ userProfile ] [ ];
  gnome = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs = {
      osConfig.services.desktopManager.gnome.enable = true;
    };
    modules = [
      ../modules/integrations/gnome-chinese.nix
      {
        software.platform = "nixos";
        home = {
          username = "test";
          homeDirectory = "/home/test";
          stateVersion = "26.05";
        };
        i18n.inputMethod = {
          enable = true;
          type = "fcitx5";
        };
      }
    ];
  };
  session = pkgs.writeText "gnome-input-environment.sh" gnome.config.home.sessionVariablesExtra;
in
assert !(disabled.xdg.dataFile ? applications);
pkgs.runCommand "desktop-boundaries-check"
  {
    nativeBuildInputs = [
      pkgs.desktop-file-utils
      pkgs.python3
    ];
  }
  ''
    filtered=${filtered.desktop.launcher.entries}/share/applications
    test -f "$filtered/vim.desktop"
    test ! -e "$filtered/absent.desktop"
    test ! -e "$filtered/visible.desktop"
    test -z "$(ls -A ${absent.desktop.launcher.entries}/share/applications)"
    desktop-file-validate "$filtered/vim.desktop"
    python - ${userProfile}/share/applications/vim.desktop "$filtered/vim.desktop" <<'PY'
    import configparser
    import sys
    def read(path):
        cfg = configparser.ConfigParser(interpolation=None)
        cfg.optionxform = str
        cfg.read(path)
        return dict(cfg['Desktop Entry'])
    original, hidden = map(read, sys.argv[1:])
    assert hidden.pop('NoDisplay') == 'true'
    hidden.pop('X-Desktop-File-Install-Version', None)
    assert original == hidden, (original, hidden)
    PY
    (
      unset GTK_IM_MODULE
      export XDG_CURRENT_DESKTOP=GNOME
      . ${session}
      test "$GTK_IM_MODULE" = fcitx
    )
    (
      unset GTK_IM_MODULE
      export XDG_CURRENT_DESKTOP=GNOME-Classic:GNOME
      . ${session}
      test "$GTK_IM_MODULE" = fcitx
    )
    for desktop in niri KDE ""; do
      (
        unset GTK_IM_MODULE
        export XDG_CURRENT_DESKTOP="$desktop"
        . ${session}
        test -z "''${GTK_IM_MODULE+x}"
      )
    done
    (
      export XDG_CURRENT_DESKTOP=GNOME GTK_IM_MODULE=custom
      . ${session}
      test "$GTK_IM_MODULE" = custom
    )
    touch "$out"
  ''
