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
  fcitx5-rime.nix = nix (pkgs.fcitx5-rime.override { rimeDataPkgs = [ pkgs.rime-ice ]; });
  dms.nix = nix pkgs.dms-shell;

  efibootmgr.pacman = pacman "efibootmgr";
  nautilus.pacman = pacman "nautilus";
  wl-clipboard.pacman = pacman "wl-clipboard";
  xdg-terminal-exec.pacman = pacman "xdg-terminal-exec";
} (builtins.attrValues profiles)
