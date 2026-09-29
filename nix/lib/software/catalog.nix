{ pkgs }:
let
  inherit (pkgs) lib;
  inherit (import ./recipes.nix { inherit pkgs; })
    nix
    font
    cask
    brew
    pacman
    aur
    ;
  profiles = import ./profiles.nix { inherit pkgs; };
in
# Shared entries in profiles reuse the same recipe, so software has one identity.
lib.foldl' (catalog: profile: catalog // profile) {
  procps = {
    nix = nix pkgs.procps;
    pacman = pacman "procps-ng";
  };
  vim = {
    nix = nix pkgs.vim;
    homebrew = brew "vim";
    pacman = pacman "vim";
  };
  zsh = {
    nix = nix pkgs.zsh;
    homebrew = brew "zsh";
    pacman = pacman "zsh";
  };
  gnupg = {
    nix = nix pkgs.gnupg;
    homebrew = brew "gnupg";
    pacman = pacman "gnupg";
  };
  nh = {
    nix = nix pkgs.nh;
  };
  gnome-keyring = {
    nix = nix pkgs.gnome-keyring;
    pacman = pacman "gnome-keyring" // {
      capabilities = [ "systemd-service" ];
    };
  };
  khal = {
    nix = nix pkgs.khal;
    pacman = pacman "khal";
  };
  nixfmt = {
    nix = nix pkgs.nixfmt;
    homebrew = brew "nixfmt";
  };
  mpv = {
    nix = nix pkgs.mpv;
    homebrew = brew "mpv";
    pacman = pacman "mpv";
  };
  pinentry = {
    pacman = pacman "pinentry";
    nix = nix (if pkgs.stdenv.hostPlatform.isDarwin then pkgs.pinentry_mac else pkgs.pinentry-qt);
    homebrew = brew "pinentry-mac";
  };
  ghostty = {
    nix = nix pkgs.ghostty // {
      capabilities = [
        "store-package"
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ "systemd-service" ];
    };
    homebrew = cask "ghostty";
    dependencies = [ "maple-mono" ];
    pacman = pacman "ghostty";
  };
  maple-mono = {
    nix = font pkgs.maple-mono.NF-CN;
    pacman = aur "maplemono-nf-cn" // {
      capabilities = [ "font" ];
    };
    homebrew = cask "font-maple-mono-nf-cn" // {
      capabilities = [ "font" ];
    };
  };
  maple-mono-plain = {
    nix = font pkgs.maple-mono.truetype;
    pacman = aur "maplemono-ttf" // {
      capabilities = [ "font" ];
    };
    homebrew = cask "font-maple-mono" // {
      capabilities = [ "font" ];
    };
  };
  chrome = {
    nix = nix pkgs.google-chrome;
    pacman = aur "google-chrome" // {
      available = pkgs.stdenv.hostPlatform.isx86_64;
    };
    homebrew = cask "google-chrome";
  };
  vscode = {
    nix = nix pkgs.vscode;
    dependencies = [ "maple-mono" ];
    pacman = aur "visual-studio-code-bin";
    homebrew = cask "visual-studio-code";
  };
  codex = {
    nix = nix pkgs.codex;
    homebrew = cask "codex";
  };
  coteditor = {
    homebrew = cask "coteditor";
  };
  iina = {
    nix = nix pkgs.iina;
    homebrew = cask "iina";
  };
  edge = {
    nix = nix pkgs.microsoft-edge;
    homebrew = cask "microsoft-edge";
  };
  efibootmgr.nix = nix pkgs.efibootmgr;
  nautilus.nix = nix pkgs.nautilus;
  wl-clipboard.nix = nix pkgs.wl-clipboard;
  xdg-terminal-exec.nix = nix pkgs.xdg-terminal-exec;
  source-han-sans.nix = font pkgs.source-han-sans;
  noto-cjk-sans.pacman = pacman "noto-fonts-cjk" // {
    capabilities = [ "font" ];
  };
  noto-cjk-serif.pacman = pacman "noto-fonts-cjk" // {
    capabilities = [ "font" ];
  };
  noto-emoji.pacman = pacman "noto-fonts-emoji" // {
    capabilities = [ "font" ];
  };
  noto-cjk-sans.nix = font pkgs.noto-fonts-cjk-sans;
  noto-cjk-serif.nix = font pkgs.noto-fonts-cjk-serif;
  noto-emoji.nix = font pkgs.noto-fonts-color-emoji;
  tela.nix = nix pkgs.tela-icon-theme;
  gnome-firmware.nix = nix pkgs.gnome-firmware;
  gnome-user-themes.nix = nix pkgs.gnomeExtensions.user-themes;
  gnome-dash-to-dock.nix = nix pkgs.gnomeExtensions.dash-to-dock;
  gnome-desktop-icons.nix = nix pkgs.gnomeExtensions.desktop-icons-ng-ding;
  gnome-screen-rotate.nix = nix pkgs.gnomeExtensions.screen-rotate;
  gnome-kimpanel.nix = nix pkgs.gnomeExtensions.kimpanel;
  mpv-modernx.nix = nix pkgs.mpvScripts.modernx;
  mpv-thumbfast.nix = nix pkgs.mpvScripts.thumbfast;
  fcitx5.pacman = pacman "fcitx5";
  fcitx5-rime.pacman = pacman "fcitx5-rime";
  fcitx5-gtk.pacman = pacman "fcitx5-gtk";
  fcitx5-qt.pacman = pacman "fcitx5-qt";
  rime-ice.pacman = aur "rime-ice-git";
  gnome-kimpanel.pacman = aur "gnome-shell-extension-kimpanel-git";
  fcitx5-rime.nix = nix (pkgs.fcitx5-rime.override { rimeDataPkgs = [ pkgs.rime-ice ]; });
  dms.nix = nix pkgs.dms-shell;
  dms.pacman = pacman "dms-shell-niri";
  niri.pacman = pacman "niri";
  mission-center = {
    nix = nix pkgs.mission-center;
    pacman = pacman "mission-center";
  };
  gnome-text-editor.nix = nix pkgs.gnome-text-editor;
  snapshot.nix = nix pkgs.snapshot;
  networkmanager.pacman = pacman "networkmanager";
  bluez.pacman = pacman "bluez";
  bluez-utils.pacman = pacman "bluez-utils";
  pipewire.pacman = pacman "pipewire";
  pipewire-alsa.pacman = pacman "pipewire-alsa";
  pipewire-pulse.pacman = pacman "pipewire-pulse";
  wireplumber.pacman = pacman "wireplumber";
  rtkit.pacman = pacman "rtkit";
  upower.pacman = pacman "upower";
  udisks2.pacman = pacman "udisks2";
  gvfs.pacman = pacman "gvfs";
  cups.pacman = pacman "cups";
  cups-filters.pacman = pacman "cups-filters";
  ghostscript.pacman = pacman "ghostscript";
  libusb.pacman = pacman "libusb";
  avahi.pacman = pacman "avahi";
  fwupd.pacman = pacman "fwupd";
  pcsclite.pacman = pacman "pcsclite";
  ccid.pacman = pacman "ccid";
  polkit.pacman = pacman "polkit";
  gdm.pacman = pacman "gdm";
  gnome-color-manager.pacman = pacman "gnome-color-manager";
  gnome-disk-utility.pacman = pacman "gnome-disk-utility";
  gnome-font-viewer.pacman = pacman "gnome-font-viewer";
  gnome-logs.pacman = pacman "gnome-logs";
  gnome-menus.pacman = pacman "gnome-menus";
  gnome-session.pacman = pacman "gnome-session";
  gnome-settings-daemon.pacman = pacman "gnome-settings-daemon";
  gnome-system-monitor.pacman = pacman "gnome-system-monitor";
  gnome-text-editor.pacman = pacman "gnome-text-editor";
  loupe.pacman = pacman "loupe";
  malcontent.pacman = pacman "malcontent";
  papers.pacman = pacman "papers";
  snapshot.pacman = pacman "snapshot";
  sushi.pacman = pacman "sushi";
  greetd.pacman = pacman "greetd";
  tuigreet.pacman = pacman "greetd-tuigreet";
  dms-greeter.pacman = aur "greetd-dms-greeter-git";
  gnome-shell.pacman = pacman "gnome-shell";
  gnome-control-center.pacman = pacman "gnome-control-center";
  gnome-firmware.pacman = pacman "gnome-firmware";
  gnome-user-themes.pacman = pacman "gnome-shell-extensions";
  gnome-dash-to-dock.pacman = aur "gnome-shell-extension-dash-to-dock";
  gnome-desktop-icons.pacman = pacman "gnome-shell-extension-desktop-icons-ng";
  tela.pacman = aur "tela-icon-theme";
  xwayland-satellite.pacman = pacman "xwayland-satellite";
  xdg-desktop-portal-gnome.pacman = pacman "xdg-desktop-portal-gnome";
  xdg-desktop-portal-gtk.pacman = pacman "xdg-desktop-portal-gtk";
  matugen.pacman = pacman "matugen";
  cava.pacman = pacman "cava";

  efibootmgr.pacman = pacman "efibootmgr";
  nautilus.pacman = pacman "nautilus";
  wl-clipboard.pacman = pacman "wl-clipboard";
  xdg-terminal-exec.pacman = pacman "xdg-terminal-exec";
} (builtins.attrValues profiles)
