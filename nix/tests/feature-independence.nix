{ lib, build }:

let
  names = builtins.attrNames (import ../lib/features/catalog.nix).features;
  allOff = lib.genAttrs names (_: false);
  home = cfg: cfg.home-manager.users.test;
  hasPackage = name: cfg: builtins.elem name (map lib.getName (home cfg).home.packages);
  plainGit =
    cfg:
    hasPackage "git" cfg
    && !(home cfg).programs.git.enable
    && !(((home cfg).programs.git.settings.alias or { }) ? lg)
    && !(((home cfg).programs.git.settings.user or { }) ? email);
  desktopServices =
    cfg:
    cfg.networking.networkmanager.enable
    && !cfg.networking.useNetworkd
    && !cfg.systemd.network.enable
    && !(cfg.systemd.services.dhcpcd.enable or false)
    && cfg.networking.networkmanager.dns == "systemd-resolved"
    && cfg.services.resolved.enable
    && builtins.elem "networkmanager" cfg.users.users.test.extraGroups
    && cfg.security.rtkit.enable
    && cfg.services.pipewire.enable
    && cfg.services.pipewire.alsa.enable
    && cfg.services.pipewire.pulse.enable
    && cfg.hardware.bluetooth.enable
    && cfg.services.upower.enable
    && cfg.services.udisks2.enable
    && cfg.services.gvfs.enable
    && (home cfg).gtk.enable
    && (home cfg).gtk.iconTheme.name == "Tela"
    && hasPackage "tela-icon-theme" cfg
    && (home cfg).dconf.settings."org/gnome/desktop/interface".icon-theme == "Tela";
  checks = {
    plymouth =
      cfg:
      cfg.boot.plymouth.enable
      && builtins.elem "splash" cfg.boot.kernelParams
      && cfg.environment.etc ? "plymouth/plymouthd.conf";
    network =
      cfg:
      cfg.networking.useNetworkd
      && cfg.systemd.network.enable
      && cfg.services.resolved.enable
      && !cfg.networking.networkmanager.enable
      && !cfg.networking.dhcpcd.enable;
    git = cfg: (home cfg).programs.git.enable && (home cfg).programs.git.settings.alias ? lg;
    shell =
      cfg: (home cfg).programs.zsh.enable && (home cfg).programs.zsh.oh-my-zsh.enable && plainGit cfg;
    devel =
      cfg:
      plainGit cfg
      && lib.all (name: hasPackage name cfg) [
        "clang-wrapper"
        "clang-tools"
        "llvm"
        "lldb"
        "cmake"
        "python3"
        "ripgrep"
      ];
    gpg =
      cfg:
      (home cfg).programs.gpg.enable
      && (home cfg).services.gpg-agent.enable
      && lib.getName (home cfg).services.gpg-agent.pinentry.package == "pinentry-qt"
      && !(home cfg).services.gpg-agent.enableSshSupport;
    gpgSshSupport =
      cfg:
      (home cfg).services.gpg-agent.enable
      && (home cfg).services.gpg-agent.enableSshSupport
      && lib.getName (home cfg).services.gpg-agent.pinentry.package == "pinentry-qt";
    nixTools = cfg: (home cfg).programs.nh.enable && hasPackage "nixfmt" cfg && plainGit cfg;
    smartcard = cfg: cfg.services.pcscd.enable && !(home cfg).programs.gpg.enable;
    nixLd = cfg: cfg.programs.nix-ld.enable;
    gnome =
      cfg:
      cfg.services.desktopManager.gnome.enable
      && cfg.services.displayManager.gdm.enable
      && (home cfg).programs.gnome-shell.enable
      && !(home cfg).dconf.settings."org/gnome/shell".disable-user-extensions
      &&
        lib.all
          (
            id:
            builtins.elem id (
              map (v: v.value) (home cfg).dconf.settings."org/gnome/shell".enabled-extensions.value
            )
          )
          [
            "user-theme@gnome-shell-extensions.gcampax.github.com"
            "dash-to-dock@micxgx.gmail.com"
            "ding@rastersoft.com"
          ]
      && (home cfg).xdg.userDirs.enable
      && (home cfg).xdg.userDirs.createDirectories
      && desktopServices cfg;
    niri =
      cfg:
      cfg.programs.niri.enable
      && desktopServices cfg
      && (home cfg).wayland.windowManager.niri.enable
      && hasPackage "ghostty" cfg
      && !(home cfg).programs.ghostty.enable
      && !((home cfg).programs.ghostty.settings ? theme)
      && !((home cfg).programs.ghostty.settings ? window-decoration)
      && (home cfg).xdg.userDirs.enable
      && (home cfg).xdg.terminal-exec.enable
      && !(home cfg).xdg.localBinInPath
      && !cfg.programs.dms-shell.enable;
    dms =
      cfg:
      cfg.programs.dms-shell.enable
      && cfg.programs.niri.enable
      && cfg.services.displayManager.dms-greeter.enable
      && cfg.services.displayManager.defaultSession == "niri"
      && desktopServices cfg
      && !(home cfg).wayland.windowManager.niri.enable;
    ghostty =
      cfg:
      (home cfg).programs.ghostty.enable
      && (home cfg).fonts.fontconfig.enable
      && (home cfg).programs.ghostty.settings ? theme
      && !((home cfg).programs.ghostty.settings ? window-decoration);
    mpv =
      cfg:
      (home cfg).programs.mpv.enable
      && (home cfg).programs.mpv.scripts != [ ]
      && (home cfg).fonts.fontconfig.enable;
    chinese =
      cfg:
      (home cfg).home.language.base == "zh_CN.UTF-8"
      && (home cfg).i18n.inputMethod.enable
      && (home cfg).i18n.inputMethod.type == "fcitx5"
      && (home cfg).i18n.inputMethod.fcitx5.addons != [ ]
      && (home cfg).fonts.fontconfig.enable
      && hasPackage "MapleMono-NF-CN" cfg;
    xdg = cfg: (home cfg).xdg.enable && (home cfg).xdg.localBinInPath && (home cfg).xdg.userDirs.enable;
  };
  verify =
    name:
    let
      cfg = build {
        features = allOff // {
          ${name} = true;
        };
      };
      assertions = cfg.assertions ++ (home cfg).assertions;
    in
    assert lib.assertMsg (lib.all (a: a.assertion) assertions)
      "Independent feature assertion failed: ${name}\n${
        lib.concatMapStringsSep "\n" (a: a.message) (lib.filter (a: !a.assertion) assertions)
      }";
    assert lib.assertMsg (checks.${name}
      cfg
    ) "Feature depends on another feature's customization: ${name}";
    name;
in
assert names == builtins.attrNames checks;
map verify names
