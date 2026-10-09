{ pkgs }:
let
  inherit (pkgs) lib;
  inherit (import ./recipe-constructors.nix)
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
lib.foldl'
  (
    catalog: profile:
    lib.foldlAttrs (
      result: name: recipe:
      if result ? ${name} then
        assert lib.assertMsg (
          result.${name} == recipe
        ) "Software catalog: conflicting recipes for '${name}'.";
        result
      else
        result // { ${name} = recipe; }
    ) catalog profile
  )
  {
    mihomo = {
      nix = nix pkgs.mihomo;
      pacman = aur "mihomo";
      homebrew = brew "mihomo";
    };
    accountsservice = {
      pacman = pacman "accountsservice";
    };
    avahi = {
      pacman = pacman "avahi";
    };
    bubblewrap = {
      pacman = pacman "bubblewrap";
    };
    bluez = {
      pacman = pacman "bluez";
    };
    bluez-utils = {
      pacman = pacman "bluez-utils";
    };
    cava = {
      pacman = pacman "cava";
    };
    ccid = {
      pacman = pacman "ccid";
    };
    chrome = {
      nix = nix pkgs.google-chrome;
      pacman = aur "google-chrome" // {
        available = pkgs.stdenv.hostPlatform.isx86_64;
      };
      homebrew = cask "google-chrome";
    };
    codex = {
      nix = nix pkgs.codex;
      homebrew = cask "codex";
    };
    coteditor = {
      homebrew = cask "coteditor";
    };
    ctags = {
      nix = nix pkgs.universal-ctags;
      homebrew = brew "universal-ctags";
      pacman = pacman "ctags";
    };
    cups = {
      pacman = pacman "cups";
    };
    cups-filters = {
      pacman = pacman "cups-filters";
    };
    dms = {
      nix = nix pkgs.dms-shell;
      pacman = pacman "dms-shell-niri";
    };
    dms-greeter = {
      pacman = aur "greetd-dms-greeter-git";
    };
    edge = {
      nix = nix pkgs.microsoft-edge;
      homebrew = cask "microsoft-edge";
    };
    efibootmgr = {
      nix = nix pkgs.efibootmgr;
      pacman = pacman "efibootmgr";
    };
    fcitx5 = {
      pacman = pacman "fcitx5";
    };
    fcitx5-gtk = {
      pacman = pacman "fcitx5-gtk";
    };
    fcitx5-qt = {
      pacman = pacman "fcitx5-qt";
    };
    fcitx5-rime = {
      pacman = pacman "fcitx5-rime";
      nix = nix (pkgs.fcitx5-rime.override { rimeDataPkgs = [ pkgs.rime-ice ]; });
    };
    fwupd = {
      pacman = pacman "fwupd";
    };
    gdm = {
      pacman = pacman "gdm";
    };
    ghostscript = {
      pacman = pacman "ghostscript";
    };
    ghostty = {
      nix = nix pkgs.ghostty // {
        capabilities = [
          "store-package"
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ "systemd-service" ];
      };
      homebrew = cask "ghostty";
      pacman = pacman "ghostty";
    };
    gnome-color-manager = {
      pacman = pacman "gnome-color-manager";
    };
    gnome-control-center = {
      pacman = pacman "gnome-control-center";
    };
    gnome-dash-to-dock = {
      nix = nix pkgs.gnomeExtensions.dash-to-dock;
      pacman = aur "gnome-shell-extension-dash-to-dock";
    };
    gnome-desktop-icons = {
      nix = nix pkgs.gnomeExtensions.desktop-icons-ng-ding;
      pacman = pacman "gnome-shell-extension-desktop-icons-ng";
    };
    gnome-disk-utility = {
      pacman = pacman "gnome-disk-utility";
    };
    gnome-firmware = {
      nix = nix pkgs.gnome-firmware;
      pacman = pacman "gnome-firmware";
    };
    gnome-font-viewer = {
      pacman = pacman "gnome-font-viewer";
    };
    gnome-keyring = {
      nix = nix pkgs.gnome-keyring;
      pacman = pacman "gnome-keyring" // {
        capabilities = [ "systemd-service" ];
      };
    };
    gnome-kimpanel = {
      nix = nix pkgs.gnomeExtensions.kimpanel;
      pacman = aur "gnome-shell-extension-kimpanel-git";
    };
    gnome-logs = {
      pacman = pacman "gnome-logs";
    };
    gnome-menus = {
      pacman = pacman "gnome-menus";
    };
    gnome-screen-rotate = {
      nix = nix pkgs.gnomeExtensions.screen-rotate;
    };
    gnome-session = {
      pacman = pacman "gnome-session";
    };
    gnome-settings-daemon = {
      pacman = pacman "gnome-settings-daemon";
    };
    gnome-shell = {
      pacman = pacman "gnome-shell";
    };
    gnome-system-monitor = {
      nix = nix pkgs.gnome-system-monitor;
      pacman = pacman "gnome-system-monitor";
    };
    gnome-text-editor = {
      nix = nix pkgs.gnome-text-editor;
      pacman = pacman "gnome-text-editor";
    };
    gnome-user-themes = {
      nix = nix pkgs.gnomeExtensions.user-themes;
      pacman = pacman "gnome-shell-extensions";
    };
    gnupg = {
      nix = nix pkgs.gnupg;
      homebrew = brew "gnupg";
      pacman = pacman "gnupg";
    };
    greetd = {
      pacman = pacman "greetd";
    };
    gvfs = {
      pacman = pacman "gvfs";
    };
    iina = {
      nix = nix pkgs.iina;
      homebrew = cask "iina";
    };
    khal = {
      nix = nix pkgs.khal;
      pacman = pacman "khal";
    };
    libusb = {
      pacman = pacman "libusb";
    };
    loupe = {
      pacman = pacman "loupe";
    };
    malcontent = {
      pacman = pacman "malcontent";
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
    matugen = {
      pacman = pacman "matugen";
    };
    mpv = {
      nix = nix pkgs.mpv;
      homebrew = brew "mpv";
      pacman = pacman "mpv";
    };
    mpv-modernx = {
      nix = nix pkgs.mpvScripts.modernx;
    };
    mpv-thumbfast = {
      nix = nix pkgs.mpvScripts.thumbfast;
    };
    nautilus = {
      nix = nix pkgs.nautilus;
      pacman = pacman "nautilus";
    };
    networkmanager = {
      pacman = pacman "networkmanager";
    };
    nh = {
      nix = nix pkgs.nh;
    };
    noctalia-greeter = {
      nix = nix pkgs.noctalia-greeter;
      pacman = aur "noctalia-greeter";
    };
    noctalia = {
      nix = nix pkgs.noctalia;
      pacman = pacman "noctalia";
    };
    niri = {
      pacman = pacman "niri";
    };
    nixfmt = {
      nix = nix pkgs.nixfmt;
      homebrew = brew "nixfmt";
    };
    noto-cjk-sans = {
      pacman = pacman "noto-fonts-cjk" // {
        capabilities = [ "font" ];
      };
      nix = font pkgs.noto-fonts-cjk-sans;
    };
    noto-cjk-serif = {
      pacman = pacman "noto-fonts-cjk" // {
        capabilities = [ "font" ];
      };
      nix = font pkgs.noto-fonts-cjk-serif;
    };
    noto-emoji = {
      pacman = pacman "noto-fonts-emoji" // {
        capabilities = [ "font" ];
      };
      nix = font pkgs.noto-fonts-color-emoji;
    };
    papers = {
      pacman = pacman "papers";
    };
    pcsclite = {
      pacman = pacman "pcsclite";
    };
    pinentry = {
      pacman = pacman "pinentry" // {
        mainProgram = "pinentry";
      };
      nix = nix (if pkgs.stdenv.hostPlatform.isDarwin then pkgs.pinentry_mac else pkgs.pinentry-qt);
      homebrew = brew "pinentry-mac" // {
        mainProgram = "pinentry-mac";
      };
    };
    pipewire = {
      pacman = pacman "pipewire";
    };
    pipewire-alsa = {
      pacman = pacman "pipewire-alsa";
    };
    pipewire-pulse = {
      pacman = pacman "pipewire-pulse";
    };
    polkit = {
      pacman = pacman "polkit";
    };
    procps = {
      nix = nix pkgs.procps;
      pacman = pacman "procps-ng";
    };
    rime-ice = {
      pacman = aur "rime-ice-git";
    };
    rtkit = {
      pacman = pacman "rtkit";
    };
    seahorse = {
      pacman = pacman "seahorse";
    };
    snapshot = {
      nix = nix pkgs.snapshot;
      pacman = pacman "snapshot";
    };
    source-han-sans = {
      nix = font pkgs.source-han-sans;
    };
    sushi = {
      pacman = pacman "sushi";
    };
    tela = {
      nix = nix pkgs.tela-icon-theme;
      pacman = aur "tela-icon-theme";
    };
    tuigreet = {
      pacman = pacman "greetd-tuigreet";
    };
    udisks2 = {
      pacman = pacman "udisks2";
    };
    upower = {
      pacman = pacman "upower";
    };
    vim = {
      nix = nix pkgs.vim;
      homebrew = brew "vim";
      pacman = pacman "vim";
    };
    vscode = {
      nix = nix pkgs.vscode;
      pacman = aur "visual-studio-code-bin";
      homebrew = cask "visual-studio-code";
    };
    wireplumber = {
      pacman = pacman "wireplumber";
    };
    wl-clipboard = {
      nix = nix pkgs.wl-clipboard;
      pacman = pacman "wl-clipboard";
    };
    xdg-desktop-portal-gnome = {
      pacman = pacman "xdg-desktop-portal-gnome";
    };
    xdg-desktop-portal-gtk = {
      pacman = pacman "xdg-desktop-portal-gtk";
    };
    xdg-terminal-exec = {
      nix = nix pkgs.xdg-terminal-exec;
      pacman = pacman "xdg-terminal-exec";
    };
    xwayland-satellite = {
      pacman = pacman "xwayland-satellite";
    };
    zsh = {
      nix = nix pkgs.zsh;
      homebrew = brew "zsh";
      pacman = pacman "zsh";
    };
  }
  (builtins.attrValues profiles)
