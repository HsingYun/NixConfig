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
      ../ports/nixos/home/gnome-chinese.nix
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
          fcitx5.settings.inputMethod."Groups/0".DefaultIM = "rime";
        };
      }
    ];
  };
  session = pkgs.writeText "gnome-input-environment.sh" gnome.config.home.sessionVariablesExtra;
  oldFcitx = pkgs.linkFarm "fcitx-config" {
    profile = pkgs.writeText "fcitx5-profile" "previous configuration";
  };
  oldFcitxFiles = pkgs.linkFarm "home-manager-files" { ".config/fcitx5" = oldFcitx; };
  fcitxFiles = pkgs.linkFarm "home-manager-files" {
    ".config/fcitx5" = gnome.config.xdg.configFile.fcitx5.source;
  };
  perFileFcitxFiles = pkgs.linkFarm "home-manager-files" {
    ".config/fcitx5/profile" = "${gnome.config.xdg.configFile.fcitx5.source}/profile";
  };
  fcitxCheck = pkgs.writeText "check-fcitx-links.sh" gnome.config.home.activation.checkLinkTargets.data;
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
    # Reproduce an existing HM directory link. Official directory ownership
    # accepts it; switching to individual files triggers the reported conflict.
    (
      export HOME="$TMPDIR/fcitx-home"
      export HOME_MANAGER_BACKUP_EXT="" HOME_MANAGER_BACKUP_COMMAND="" HOME_MANAGER_BACKUP_OVERWRITE=""
      mkdir -p "$HOME/.config" "$TMPDIR/fcitx-generation"
      export newGenPath="$TMPDIR/fcitx-generation"
      ln -s ${oldFcitxFiles}/.config/fcitx5 "$HOME/.config/fcitx5"
      ln -s ${fcitxFiles} "$newGenPath/home-files"
      bash ${fcitxCheck}
      ln -sfn ${perFileFcitxFiles} "$newGenPath/home-files"
      if bash ${fcitxCheck} > conflict.log 2>&1; then
        echo "Expected a conflict when changing to per-file ownership" >&2
        exit 1
      fi
      grep -F "fcitx5/profile' would be clobbered" conflict.log
      test "$(cat "$HOME/.config/fcitx5/profile")" = "previous configuration"
      # An unrelated user-owned link still fails: no backup or force override.
      ln -sfn ${fcitxFiles} "$newGenPath/home-files"
      mkdir "$HOME/personal-fcitx"
      ln -sfn "$HOME/personal-fcitx" "$HOME/.config/fcitx5"
      if bash ${fcitxCheck} > conflict.log 2>&1; then
        echo "Expected protection of an unrelated directory link" >&2
        exit 1
      fi
      grep -F "fcitx5' would be clobbered" conflict.log
    )
    touch "$out"
  ''
