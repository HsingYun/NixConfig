{ lib, build }:

let
  catalog = (import ../lib/features/catalog.nix).features;
  names = builtins.attrNames (lib.filterAttrs (_: entry: !(entry ? software)) catalog);
  allOn = lib.genAttrs (builtins.attrNames catalog) (_: false) // lib.genAttrs names (_: true);
  home = cfg: cfg.home-manager.users.test;
  hasPackage = name: cfg: builtins.elem name (map lib.getName (home cfg).home.packages);
  hasKimpanel = cfg: lib.any (p: lib.hasInfix "kimpanel" (lib.getName p)) (home cfg).home.packages;
  hasDmsBindings =
    cfg: lib.hasAttrByPath [ "binds" "Mod+Space" ] (home cfg).wayland.windowManager.niri.settings;
  hasRime = cfg: (home cfg).xdg.dataFile ? "fcitx5/rime/default.custom.yaml";
  develPackages = [
    "clang-wrapper"
    "clang-tools"
    "llvm"
    "lld"
    "lldb"
    "cmake"
    "ninja"
    "meson"
    "gnumake"
    "autoconf"
    "automake"
    "libtool"
    "gnum4"
    "pkg-config-wrapper"
    "file"
    "patch"
    "diffutils"
    "python3"
  ];
  # Check repository-specific settings, including integrations, rather than
  # assuming that upstream defaults or shared packages disappear.
  checks = {
    printing = {
      on = cfg: cfg.services.printing.enable && cfg.services.avahi.enable;
      off =
        cfg: !cfg.services.printing.enable && !cfg.services.avahi.nssmdns4 && cfg.services.fwupd.enable;
    };
    firmware = {
      on = cfg: cfg.services.fwupd.enable && hasPackage "gnome-firmware" cfg;
      off =
        cfg:
        !cfg.services.fwupd.enable && !(hasPackage "gnome-firmware" cfg) && cfg.services.printing.enable;
    };
    commonTools = {
      on = cfg: hasPackage "aria2" cfg && hasPackage "graphviz" cfg;
      off =
        cfg:
        !(hasPackage "aria2" cfg)
        && !(hasPackage "graphviz" cfg)
        && (home cfg).programs.gpg.enable
        && hasPackage "gnupg" cfg;
    };
    launcher = {
      on = cfg: (home cfg).desktop.launcher.hiddenEntries != [ ];
      off =
        cfg: (home cfg).desktop.launcher.hiddenEntries == [ ] && !((home cfg).xdg.dataFile ? applications);
    };
    wallpaper = {
      on = cfg: (home cfg).features.desktop.wallpaper.enable;
      off = cfg: !(home cfg).features.desktop.wallpaper.enable;
    };
    keyring = {
      on = cfg: (home cfg).features.desktop.keyring.enable;
      off =
        cfg:
        !(home cfg).features.desktop.keyring.enable
        && !(home cfg).services.gnome-keyring.enable
        && !((home cfg).systemd.user.services ? gnome-keyring)
        && !cfg.services.gnome.gnome-keyring.enable;
    };
    plymouth = {
      on = cfg: cfg.boot.plymouth.enable && builtins.elem "splash" cfg.boot.kernelParams;
      off =
        cfg:
        !cfg.boot.plymouth.enable
        && !(builtins.elem "splash" cfg.boot.kernelParams)
        && !(cfg.environment.etc ? "plymouth/plymouthd.conf");
    };
    network = {
      on = cfg: cfg.services.resolved.enable;
      # Desktop profiles retain their own required networking capability.
      off =
        cfg:
        cfg.networking.networkmanager.enable
        && cfg.services.resolved.enable
        && cfg.networking.networkmanager.dns == "systemd-resolved"
        && !cfg.networking.useNetworkd;
    };
    devel = {
      on = cfg: lib.all (name: hasPackage name cfg) develPackages;
      off =
        cfg:
        lib.all (name: !(hasPackage name cfg)) develPackages
        && (home cfg).programs.git.enable
        && lib.all (name: hasPackage name cfg) [
          "ripgrep"
          "fd"
          "jq"
          "tree"
        ];
    };
    git = {
      on = cfg: (home cfg).programs.git.settings.alias ? lg;
      off =
        cfg:
        !(((home cfg).programs.git.settings.alias or { }) ? lg)
        && !(((home cfg).programs.git.settings.user or { }) ? email);
    };
    shell = {
      on = cfg: (home cfg).programs.zsh.oh-my-zsh.enable;
      off = cfg: !(home cfg).programs.zsh.oh-my-zsh.enable;
    };
    vim = {
      on = cfg: (home cfg).programs.vim.enable;
      off = cfg: !(home cfg).programs.vim.enable && !((home cfg).home.file ? ".vimrc");
    };
    gpg = {
      on = cfg: (home cfg).programs.gpg.scdaemonSettings.disable-ccid or false;
      off =
        cfg:
        (home cfg).programs.gpg.enable
        && (home cfg).services.gpg-agent.enable
        && lib.getName (home cfg).services.gpg-agent.pinentry.package == "pinentry-tty"
        && (home cfg).services.gpg-agent.enableSshSupport;
    };
    gpgSshSupport = {
      on = cfg: (home cfg).services.gpg-agent.enableSshSupport;
      off =
        cfg:
        !(home cfg).services.gpg-agent.enableSshSupport
        && (home cfg).services.gpg-agent.enable
        && cfg.services.gnome.gcr-ssh-agent.enable;
    };
    nixTools = {
      on = cfg: (home cfg).programs.nh.enable && hasPackage "nixfmt" cfg;
      off = cfg: !(home cfg).programs.nh.enable && !(hasPackage "nixfmt" cfg);
    };
    smartcard = {
      on = cfg: cfg.services.pcscd.enable && (home cfg).programs.gpg.scdaemonSettings.disable-ccid;
      off = cfg: !cfg.services.pcscd.enable && !((home cfg).programs.gpg.scdaemonSettings ? disable-ccid);
    };
    nixLd = {
      on = cfg: cfg.programs.nix-ld.enable;
      off = cfg: !cfg.programs.nix-ld.enable;
    };
    gnome = {
      on =
        cfg:
        cfg.services.displayManager.gdm.enable
        && cfg.environment.gnome.excludePackages != [ ]
        && hasKimpanel cfg;
      off =
        cfg:
        !cfg.services.desktopManager.gnome.enable
        && !cfg.services.displayManager.gdm.enable
        && cfg.environment.gnome.excludePackages == [ ]
        && !(hasKimpanel cfg)
        && !(home cfg).programs.gnome-shell.enable
        && (home cfg).programs.gnome-shell.extensions == [ ]
        && !(hasPackage "gnome-shell-extension-dash-to-dock" cfg)
        && !(hasPackage "gnome-shell-extension-desktop-icons-ng-ding" cfg)
        && !(hasPackage "gnome-shell-extension-user-themes" cfg)
        && (home cfg).gtk.iconTheme.name == "Tela"
        && lib.getName (home cfg).services.gpg-agent.pinentry.package == "pinentry-qt";
    };
    niri = {
      on = cfg: (home cfg).wayland.windowManager.niri.enable && hasDmsBindings cfg;
      off =
        cfg:
        !(home cfg).wayland.windowManager.niri.enable
        && !(hasDmsBindings cfg)
        && !((home cfg).wayland.windowManager.niri.settings ? screenshot-path)
        && cfg.programs.dms-shell.enable;
    };
    dms = {
      on = cfg: cfg.programs.dms-shell.enable && hasDmsBindings cfg;
      off =
        cfg:
        !cfg.programs.dms-shell.enable
        && !cfg.services.displayManager.dms-greeter.enable
        && !(hasDmsBindings cfg)
        && !(cfg.security.pam.services ? dankshell)
        && (home cfg).wayland.windowManager.niri.enable;
    };
    ghostty = {
      on =
        cfg:
        (home cfg).programs.ghostty.settings ? theme
        && !((home cfg).programs.ghostty.settings ? window-decoration);
      off =
        cfg:
        !((home cfg).programs.ghostty.settings ? theme)
        && !((home cfg).programs.ghostty.settings ? window-decoration)
        && !((home cfg).home.sessionVariables ? TERMINAL);
    };
    mpv = {
      on = cfg: (home cfg).programs.mpv.config ? hwdec;
      off =
        cfg:
        !((home cfg).programs.mpv.config ? hwdec)
        && (home cfg).programs.mpv.scripts == [ ]
        && !(hasPackage "source-han-sans" cfg);
    };
    chinese = {
      on = cfg: hasRime cfg && hasKimpanel cfg && (home cfg).home.language.base == "zh_CN.UTF-8";
      off =
        cfg:
        !(hasRime cfg)
        && !(hasKimpanel cfg)
        && (home cfg).home.language.base == null
        && !(home cfg).i18n.inputMethod.enable
        && (home cfg).i18n.inputMethod.fcitx5.addons == [ ]
        && !(builtins.elem "zh_CN.UTF-8/UTF-8" cfg.i18n.extraLocales)
        && !(hasPackage "noto-fonts-cjk-sans" cfg);
    };
    xdg = {
      on = cfg: (home cfg).xdg.localBinInPath && (home cfg).xdg.userDirs.enable;
      off =
        cfg:
        !(home cfg).xdg.localBinInPath
        && (home cfg).xdg.userDirs.enable
        && (home cfg).xdg.terminal-exec.enable
        && hasRime cfg;
    };
  };
  baseline = build {
    features = allOn;
    preferences = {
      desktop = "gnome";
      loginManager = "gdm";
    };
  };
  verify =
    name:
    let
      cfg = build {
        features = allOn // {
          ${name} = false;
        };
        preferences =
          if name == "gnome" then
            {
              desktop = "niri";
              loginManager = "greetd";
            }
          else
            {
              desktop = "gnome";
              loginManager = "gdm";
            };
        homeConfig =
          { lib, pkgs, ... }:
          lib.optionalAttrs (name == "gpg") {
            software.packageOverrides.pinentry = pkgs.pinentry-tty;
          };
      };
      assertions = cfg.assertions ++ (home cfg).assertions;
    in
    assert lib.assertMsg (checks.${name}.on
      baseline
    ) "Feature-off baseline is missing customization: ${name}";
    assert lib.assertMsg (lib.all (a: a.assertion) assertions)
      "Feature-off assertion failed: ${name}\n${
        lib.concatMapStringsSep "\n" (a: a.message) (lib.filter (a: !a.assertion) assertions)
      }";
    assert lib.assertMsg (checks.${name}.off cfg) "Disabled feature left customization behind: ${name}";
    name;
in
assert names == builtins.attrNames checks;
map verify names
