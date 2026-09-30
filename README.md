# NixConfig

English · [简体中文](README.zh.md)

Declarative system and user configurations for NixOS, WSL, macOS, and Linux. Hosts share a common configuration with independent feature selection and local overrides.

- NixOS / Arch desktops: GNOME or Niri with DankMaterialShell; Arch supplies native packages through pacman/AUR while Home Manager owns configuration.
- Application profiles: Git, Zsh, GPG, Ghostty, and mpv.
- Development tools (`devel`): Clang/LLVM, GCC, GDB/LLDB, build tools, Python, Go, Node.js/TypeScript, OpenJDK, Rust/Cargo, plus Git LFS, Protobuf, Abseil, coreutils, and Telnet.
- Chinese environment: Simplified Chinese locale, CJK fonts, Maple Mono, and Fcitx5 with Rime Ice.

## Platforms

| Platform | Managed scope |
| --- | --- |
| `nixos` | NixOS and Home Manager |
| `nixos-wsl` | NixOS-WSL and Home Manager |
| `darwin` | macOS through nix-darwin and Home Manager |
| `arch` | Arch user environment through Home Manager and native adapters |

`platform = "arch"` selects Arch integration; `system = "x86_64-linux"` still selects the Nix CPU/OS target. Platform definitions live in [nix/lib/hosts/platforms.nix](nix/lib/hosts/platforms.nix). The old `platform = "linux"` name is not supported.

Shared experience is defined in [nix/lib/hosts/profiles.nix](nix/lib/hosts/profiles.nix):

| Host | Default experience |
| --- | --- |
| ArchLinux | Niri + DMS + greetd; GNOME is opt-in, pacman/AUR preferred |
| NixOS-PC | The same Niri desktop and GNOME alternative; hardware remains a placeholder |
| NixOS-Pad | GNOME + GDM, screen rotation, on-screen keyboard and touchscreen orientation |
| Darwin | Shared CLI/development/GPG tools, Ghostty, Chrome, VS Code and mpv; native macOS desktop |
| NixOS-WSL | Shared CLI/development/GPG/smart-card tools, terminal pinentry; no desktop or Chinese IME |

For GNOME on PC/Arch, first enable `features.desktop.gnome.enable` in the host (off by default on Arch), then select `preferences.desktop = "gnome"; preferences.loginManager = "gdm";`. Preferences select the default desktop; they do not enable or disable features. Niri configuration can remain enabled. To use Niri on Pad, enable `desktop.niri` and `desktop.dms` and change those preferences.

## Usage

Requires Nix with flakes enabled and the configuration tool for the target platform.

```sh
git clone https://github.com/HsingYun/NixConfig.git
cd NixConfig
```

Set the shared user in [flake.nix](flake.nix) and review the target configuration in [hosts/](hosts/). For native NixOS, configure the target machine's hardware and boot loader before applying.

Run the matching command on the target machine:

| Target | Command |
| --- | --- |
| NixOS / NixOS-WSL | `sudo nixos-rebuild switch --flake .#HOST` |
| macOS | `sudo darwin-rebuild switch --flake .#HOST` |
| Linux user environment | `home-manager switch --flake .#HOST` |

Replace `HOST` with a name registered in [hosts/default.nix](hosts/default.nix).

Home Manager does not automatically back up conflicting unmanaged files. File conflicts stop activation and report an error; resolve them explicitly before retrying.

`nixos-rebuild switch` activates immediately and reports failed services. `nixos-rebuild boot` only prepares the next boot; successful completion does not confirm Home Manager activation. After reboot, check `systemctl --failed` and `systemctl status home-manager-<username>` if settings were not applied.

## Configuration

Each host selects a platform and features in `hosts/<name>/default.nix`. System settings belong in `system.nix`; user settings and packages belong in `home.nix`.

For example, enable a Niri desktop with Chinese input:

```nix
features = {
  desktop.niri.enable = true;
  desktop.dms.enable = true;
  chinese.enable = true;
  ghostty.enable = true;
};
```

Feature defaults and platform support are defined in the [feature catalog](nix/lib/features/catalog.nix). Declare only changes to the defaults. Disabling a feature removes this repository's customization without blocking other modules or deleting application data.

`features` is hierarchical: each feature has an `.enable` switch with its settings alongside it. Desktop features are grouped under `features.desktop`, including `gnome`, `niri`, `dms`, `keyring`, `launcher`, `wallpaper`, `printing`, `firmware`, and `screenRotate`; GPG SSH support is under `features.gpg.sshSupport`. Groups have no master switch. Shared defaults and host overrides merge by field; explicit `false` and empty lists replace inherited values. Boolean declarations such as `features.niri = true` have been migrated to `features.desktop.niri.enable = true`.

For example, enable Chrome with no default extensions:

```nix
features.chrome = {
  enable = true;
  extensions = [ ];
};
```

Keep these settings in `hosts/<name>/default.nix`; the resolved tree is shared with Home Manager and system modules.

Software installation is coordinated by one software layer. Hosts select `packageManager` and `features`; host-specific extras belong in `packageManager.externalPkg` using that manager’s native package names:

```nix
packageManager = {
  type = "homebrew";
  externalPkg.brews = [ "watch" ];
};
features = {
  ghostty.enable = true;
  vim.enable = true;
  chrome.enable = true;
};
```

NixOS/WSL default to Nix. Darwin prefers Homebrew, falling back to Nix when an implementation is unavailable or cannot meet a feature's capabilities. Arch defaults to `pacman`, including AUR packages installed through yay. Unimplemented managers such as `apt` are rejected explicitly. Resolution uses the software catalog, not the machine's current installation state.

Features declare both configuration and software requirements. Shared dependencies are merged: Ghostty requests Maple Mono, which can remain installed for the Chinese feature after Ghostty is disabled. Niri launches a terminal through `xdg-terminal-exec` without choosing Ghostty implicitly.

`features.vscode` installs Maple Mono and seeds the editor and integrated terminal fonts once. Existing values and JSONC comments are preserved; subsequent activations and feature toggles leave the settings user-owned. Customize the initial defaults with `features.vscode.initialSettings`. The initialization marker lives at `$XDG_STATE_HOME/nixconfig/vscode-initialized` (under `~/.local/state` by default). Named profiles, portable installations, and remote VS Code settings are not modified.

Extras matching active software requirements follow that software's selected provider and wrapper. Selected Nix commands take precedence over stale native installations. Set `software.packageOverrides.<software-id>` in the Home Manager configuration to replace a feature's Nix package consistently across its installation plan and module configuration. Arch, PC, Pad and Darwin enable `features.commonTools.enable`: aria2, GnuPG, GnuTLS, Graphviz, ncurses, OpenSSL, pinentry, rsync, SQLite, xz, zlib and zstd. It requests software without enabling GPG configuration. Provider preference and capability-based fallback remain shared. Linux procps is also provided by commonTools. Host extras retain differences such as watch and generic pinentry on Darwin; WSL selects terminal pinentry through its package binding.

The default-enabled `vim` feature uses the official `programs.vim` wrapper for Nix packages. Native pacman/Homebrew Vim reads an HM-managed `~/.vimrc` generated with nixpkgs’ Vim utilities. Both use the settings in [nix/assets/vimrc](nix/assets/vimrc) and pinned plugin sources; startup does not download plugins. Existing vim-plug directories are left untouched and no longer loaded by this configuration. Conflicting unmanaged configuration requires explicit resolution. `CodeFormat()` requires `astyle`; missing or failed formatters report an error without changing the buffer or writing the file. PC and Pad use Nix applications; Darwin prefers Homebrew, with provider-specific PATH handling generated centrally.

Disabling a feature removes its software requests while retaining shared requirements. Arch keeps packages on ordinary feature removal. Explicit application overrides to Nix remove the corresponding installed native package only after Nix installation succeeds, using plain `pacman -R` with dependency checks, no cascading removal, and no dependency bypass. Reverse dependencies, account login shells, and active/enabled native system units block removal. Homebrew keeps `cleanup = "none"`, so removing a manifest entry does not uninstall existing software. Integrations requiring a Nix package path, including Zsh, GPG agent and mpv plugins, declare that capability explicitly. Resolution reports explain fallbacks.

Inspect a host's software sources:

```sh
nix eval --json .#lib.softwarePlans.Darwin
nix eval --json .#lib.softwareManifests.Darwin
```

See the [software architecture](docs/software.md) for catalog, capability and backend-extension contracts.

Desktop settings belong to structured features:

```nix
features.desktop = {
  gnome.enable = true;
  niri.enable = true;
  dms.enable = true;
  niri.settings.layout.gaps = 12;
  gnome.settings."org/gnome/desktop/interface".clock-show-seconds = true;
  dms.settings.fontFamily = "Sans";
  launcher = {
    enable = true;
    hiddenEntries = [ "org.gnome.Tour.desktop" "org.gnome.Tecla.desktop" ];
  };
  wallpaper = {
    enable = true;
    image = /absolute/path/desktop.png;
    lockImage = /absolute/path/lock.png;
  };
};
```

Desktop features default-enable `fileManager`, `keyring`, `launcher`, `wallpaper`, `printing`, and `firmware`; each can be disabled independently. Shared wallpaper paths now live in `flake.nix` under `features.desktop.wallpaper`, replacing `user.wallpaper/lockWallpaper`. Hosts can override paths or use explicit `null` to leave an image unmanaged. GNOME and DMS share these images; the NixOS DMS greeter uses `lockImage` too. Niri alone has no wallpaper renderer; DMS renders its wallpaper here.

`features.desktop.fileManager` installs Nautilus and makes it the default file manager. `sortDirectoriesFirst`, `showHiddenFiles`, `showCreateLink`, and `showDeletePermanently` all default to `true`. Home Manager manages these preferences through dconf, covering both GTK3 and GTK4 file choosers. Arch uses pacman; NixOS uses Nix. Disabling the feature also removes the managed Niri `Mod+E` binding; already installed Arch packages remain.

`features.desktop.gnome.flatAppGrid` defaults to `true`, setting only the GNOME Overview app folder list to an explicit empty value. Folder details and app positions are preserved. Set it to `false` to stop managing the folder list. GNOME Shell recognizes an explicit empty list and does not recreate its default folders ([upstream implementation](https://github.com/GNOME/gnome-shell/blob/main/js/ui/appDisplay.js)).

GNOME's Dash to Dock defaults to a fixed bottom panel extending to the screen edges, with autohide and intellihide disabled, Shrink Dash enabled, and no overview on login. Show Applications sits at the far left. Favorites are Text Editor, Files, and Ghostty in that order; the latter two appear only when their features are enabled. Override these defaults through `features.desktop.gnome.settings` under `org/gnome/shell` and `org/gnome/shell/extensions/dash-to-dock`.

ArchLinux defaults to Niri+DMS, wallpaper, and launcher exclusions, with the GNOME feature disabled. Enabling GNOME explicitly requests GNOME Shell, GDM, and GNOME extensions from the [Arch package selection](nix/modules/home/features/gnome.nix), without installing the entire `gnome` group. Package repositories follow the host pacman configuration. HM manages desktop configuration, validates Niri configuration with the native binary, and enables Arch’s DMS user service for Niri sessions. Start Niri through its system login session or `niri-session`.

GNOME provides Mission Center (`mission-center`), Snapshot (`snapshot`), GNOME Text Editor, and Passwords and Keys (`seahorse`) on both Arch and NixOS; NixOS uses its official GNOME module for Seahorse. Ghostty is the separately managed terminal; GNOME Console is no longer requested. NixOS excludes legacy GNOME Terminal, gedit, and Cheese, whose desktop entries are also hidden by default.

The default hidden entries also cover CUPS printing management, GNOME Tecla, the Fcitx keyboard layout viewer, Fcitx 5 configuration, and its migration wizard: `cups.desktop`, `org.gnome.Tecla.desktop`, `kbd-layout-viewer5.desktop`, `fcitx5-configtool.desktop`, `org.fcitx.fcitx5-config-qt.desktop`, and `org.fcitx.fcitx5-migrator.desktop`. Only existing launcher entries are hidden; printing services, commands, and input method configuration menus remain available.

`features.desktop.printing.enable` manages CUPS and discovery; `features.desktop.firmware.enable` manages fwupd and GNOME Firmware. Both are enabled on the ArchLinux host. Arch installs native CUPS, filters, Ghostscript, libusb, Avahi, and fwupd, and enables `cups.socket`, the Avahi service/socket, and `fwupd-refresh.timer`. NixOS uses its official service modules. Firmware metadata is refreshed automatically; firmware is never flashed automatically. Printer queues, device-specific drivers, and firmware installation remain device-specific. Network printer `.local` resolution uses the host's networking configuration.

Arch service ownership is recorded under root-owned `/var/lib/nixconfig/native-systemd/`. Disabling a feature removes only boot links created by this configuration and stops units that were originally neither enabled nor active and have no remaining owner. Existing services, administrator edits, and shared dependencies are preserved. Packages remain installed. Repeated activation performs no redundant service changes, and interrupted activation can be retried. Native DBus activation remains available to other applications; services are not masked.

Arch and NixOS share the same login selection: GNOME defaults to GDM; Niri defaults to greetd, with a DMS greeter when DMS is enabled and tuigreet otherwise. When multiple providers are enabled, select one explicitly. The Arch host uses:

```nix
preferences = {
  desktop = "niri";
  loginManager = "greetd"; # "gdm" for GDM; "none" for unmanaged/manual login
};
```

On Arch, activation installs the chosen greeter, writes dedicated greetd configuration when selected, and uses sudo to enable one login manager and graphical.target. Switching replaces the old manager’s boot links without restarting the running session; the new manager takes effect after reboot. The dedicated greetd service drop-in uses `/etc/greetd/nixconfig.toml`; the original `/etc/greetd/config.toml` is preserved. Selecting `none` or removing the desktop feature leaves existing native login services untouched. Existing PAM rules and network connection configuration remain host-managed.

`features.desktop.dms.settings` and `.session` map to the corresponding HM options. Nonempty values manage JSON files declaratively (read-only). To let DMS save its own settings, disable the wallpaper feature and clear the corresponding feature parameters, or use `lib.mkForce { }` on the HM option in `home.nix`. The Arch adapter manages settings, session, clipboard JSON and user services; NixOS retains the full upstream HM interface.

The catalog declares a fixed default list, including Avahi’s `avahi-discover.desktop`, `bssh.desktop`, `bvnc.desktop`, legacy GNOME Terminal/gedit/Cheese, and `org.gnome.Tour.desktop`, `org.gnome.Tecla.desktop`, `org.gnome.Epiphany.desktop`, `org.gnome.Software.desktop`, plus `htop.desktop`, `nvtop.desktop`, `cmake-gui.desktop`, `lstopo.desktop`, `jconsole-java-openjdk.desktop`, `jshell-java-openjdk.desktop`, and vim/gvim entries. These Arch filenames were checked against installed packages; runtime discovery does not add applications to the fixed list. `features.desktop.launcher.hiddenEntries` replaces this list and hides existing entries using `NoDisplay=true`, preserving commands, associations and actions. Nix package entries are read during builds; native Arch entries are read after package installation on each HM activation. On Arch, both sources use the same checksum-tracked override owner, avoiding link-preflight collisions when changing providers. NixOS uses Home Manager links to the build-time output, without native filesystem scanning. Removing rules, disabling the feature, or removing source entries cleans up unchanged generated native copies. Existing user files and other symlinks are preserved.

Chinese input is supported on native Arch/NixOS desktops, not WSL. Both use the working local Rime setup: a single Rime input-method entry, the Ice preset, and English mode by default, preserving personal dictionaries. Set `features.chinese.englishByDefault = false;` for Chinese by default; `.settings` overrides Fcitx `inputMethod`, `globalOptions`, and `addons`. Arch uses native Fcitx, GTK/Qt modules, Rime and rime-ice-git; NixOS uses the official Home Manager Fcitx5 module for settings, directory links, and its user service. Arch renders the shared settings in its native adapter without enabling the Nix runtime. Both GNOME desktops receive Kimpanel, XSettings and session-specific GTK configuration. Niri uses Wayland input support without globally setting GTK_IM_MODULE. A session-bound user unit owns Fcitx startup, suppressing duplicate XDG autostart. Arch retains that managed suppression when the feature is disabled because the native package remains installed; a host that never enabled the feature is untouched.

Arch desktops also request NetworkManager, PipeWire/WirePlumber, Bluetooth, UPower, UDisks and GVfs. HM manages audio user units. An active alternative network manager causes a read-only preflight failure instead of interrupting the current connection. NetworkManager-wait-online is enabled for boot without running it during activation.

Native Niri/session/portal and Keyring packages must stay consistent with their OS integration. Arch rejects Nix overrides for these system components. Customize NixOS Keyring through a system nixpkgs overlay so PAM, DBus, wrappers and the user unit share one package. Standalone Nix Keyring requires `useWrappedDaemon = false`.

NixOS uses the official Home Manager dconf activation. Declared settings are applied on activation; removed keys reset to defaults while the upstream activation remains enabled. In the pinned HM version, removing every dconf database omits that activation, so previous values can remain. Arch alone uses the value-tracking adapter: removing settings restores their original values only when they still match the managed write, including removal of the last database.

ArchLinux enables `features.mpv.enable` with the pacman player. HM manages `mpv.conf`, script options and links under `mpv/scripts`; ModernX, thumbfast and fonts retain their pinned Nix sources without installing a Nix player. Thumbnail generation explicitly uses `/usr/bin/mpv`. See the [mpv file layout](https://mpv.io/manual/stable/#files). NixOS/macOS retain their Nix wrapper integration.

Native NixOS enables `network` by default: systemd-networkd with systemd-resolved. Desktop features share this capability and default to NetworkManager with systemd-resolved. Set `networking.networkmanager.enable` in `system.nix` to select NetworkManager (`true`) or networkd (`false`) independently of the desktop. Arch desktops manage native NetworkManager through the desktop adapter. WSL, macOS, and standalone Home Manager without that adapter retain their platform's network management.

On native NixOS and Arch, the `chrome` feature defaults HTTP, HTTPS and HTML associations to Google Chrome. Override individual desktop entries with `xdg.mimeApps.defaultApplications` in `home.nix`, or set `xdg.mimeApps.enable = false` to manage default applications through the desktop settings.

The `chrome` feature also installs Bitwarden by default. Set `features.chrome.extensions = [ ];` in the host’s `default.nix` to disable this, or supply other Chrome Web Store extension IDs. Linux uses Chrome's `normal_installed` policy, which installs extensions automatically but lets users disable them. NixOS manages the policy declaratively. Arch activation uses sudo to reconcile `/etc/opt/chrome/policies/managed/nixconfig-extensions.json` for all Chrome users on the machine. Root-owned records track content, file identity and configuration owners; unmanaged files, administrator edits and symlinked paths are rejected. Identical content is not rewritten. Disabling the extensions or `chrome` removes only the unchanged owned policy when no other configuration owner needs it. macOS uses user-level External Extensions manifests and may ask for confirmation when Chrome starts. See the [Chrome policy documentation](https://support.google.com/chrome/a/answer/7517525?hl=en) and [external extension documentation](https://developer.chrome.com/docs/extensions/how-to/distribute/install-extensions).

GNOME Keyring is a shared Home Manager desktop capability implemented in [keyring.nix](nix/modules/home/shared/keyring.nix). Use `features.desktop.keyring.enable = true;` in the host’s `default.nix`, or `false` to disable it. GNOME and Niri desktops default to enabled, and the ArchLinux host opts in as well. The module uses the software layer's selected provider: pacman uses native `gnome-keyring-daemon.service` and `.socket` units enabled under `default.target` and `sockets.target`; Nix uses the official Home Manager `services.gnome-keyring` module and its `gnome-keyring.service`, started with the graphical session. The NixOS adapter only supplies PAM, D-Bus and portal integration. Only password and certificate components are enabled; SSH remains with the existing agent configuration. Automatic login unlocking depends on the login manager's PAM configuration.

To add a host, follow [Creating hosts](docs/hosts.md), which covers deployment platforms, CPU architectures, state versions and validation.

Smart cards use `features.smartcard` on every supported platform. ArchLinux explicitly enables it, installs native `pcsclite`, `ccid`, and `polkit`, and manages `pcscd.socket` through the shared unit adapter. GPG uses PC/SC when enabled. Ordinary desktop sessions do not receive additional Polkit grants. For Arch-WSL or remote SSH, opt into `features.smartcard.allowBackgroundAccess = true;`: the rule allows only the configured account and the two PC/SC actions. See the [Arch-WSL guide](docs/hosts.md#arch-under-wsl) and [ArchWiki GnuPG](https://wiki.archlinux.org/title/GnuPG#Using_a_smart_card_on_a_remote_client). Disabling the option removes only an unchanged managed policy. WSL still needs device forwarding.

Reusable activation helpers live in [nix/assets/helpers](nix/assets/helpers), with feature behavior and platform adapters kept in their respective modules.

## Layout

```text
flake.nix      Dependencies and shared user settings
hosts/         Machine configurations
nix/
  modules/     System, user, and feature modules
  lib/         Configuration assembly and software resolution
  tests/       Configuration checks
```

## Validation

First evaluate every platform, including the complete system or Home Manager activation output of each registered host:

```sh
nix flake check --no-build --all-systems
```

Then build and run checks for the current platform:

```sh
nix flake check --print-build-logs
```

CI runs native checks on x86_64 Linux and Apple Silicon macOS. The `host-*` checks evaluate complete host outputs and their assertions. The `home-profile-*` checks build each host's actual Home Manager package directory to catch file collisions; they do not activate it or build the entire system. `--no-build` cannot detect these collisions. Feature tests exercise independent toggles individually and retain local combinations for dependencies, conflicts, and desktop choices.

Before deployment, build the actual output on its matching platform, for example:

```sh
nix build .#darwinConfigurations.Darwin.system --no-link
nix build .#homeConfigurations.ArchLinux.activationPackage --no-link
nix build .#nixosConfigurations.NixOS-Pad.config.system.build.toplevel --no-link
```

Cross-platform builds require a matching remote builder. These commands do not switch the current system.

## License

[Apache License 2.0](LICENSE) · Copyright © 2026 HsingYun
