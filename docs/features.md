# Configuring features

Declare features in `hosts/<name>/default.nix`. Each feature has an `enable`
option and, where applicable, adjacent settings. Groups such as `desktop` have
no master switch. The [catalog](../nix/lib/features/catalog.nix) is the source of
truth for defaults, supported platforms and option names. See [host creation](hosts.md)
for composition and [software architecture](software.md) for ownership and lifecycle.

## Desktop selection

`linuxDesktop` selects Niri + DMS with greetd. PC and Arch use that preset; Pad
replaces it with GNOME + GDM. Multiple desktop features may coexist. The default
stack is selected as a pair: Niri uses greetd, and GNOME uses GDM. Niri has
priority when both are enabled; `preferences.desktop = "gnome";` selects the
GNOME/GDM pair instead, while retaining the other enabled desktops. Preferences
do not enable or disable features. DMS adds the Niri greeter UI rather than
competing as another desktop. When removing a stack, explicitly disable it and
its dependent features. The [GNOME tablet example](hosts.md#native-nixos-pc-or-tablet)
shows a complete override.

Niri settings use structured KDL, GNOME settings use dconf schema paths, and DMS
settings use JSON attributes. For a Niri desktop:

```nix
features.desktop = {
  niri = {
    enable = true;
    settings.layout.gaps = 12;
  };
  dms = {
    enable = true;
    settings.fontFamily = "Sans";
  };
};
```

GNOME hosts can set
`features.desktop.gnome.settings."org/gnome/desktop/interface".clock-show-seconds = true;`.
`screenRotate` requires GNOME; sensor offsets and touchscreen calibration belong
to the individual host. NixOS-Pad contains the Pocket 4-specific values.

## Desktop preferences

Desktop selection supplies defaults for `fileManager`, `keyring`, `launcher`,
`wallpaper`, `printing` and `firmware`. Each can be disabled independently.

- `fileManager` selects Nautilus. `sortDirectoriesFirst`, `showHiddenFiles`,
  `showCreateLink` and `showDeletePermanently` default to true. It also supplies
  the managed Niri file-manager shortcut and directory MIME association.
- GNOME's `flatAppGrid` manages only the Overview folder list. Folder contents
  and application positions are preserved. Dash to Dock defaults to a fixed,
  full-width bottom panel; customize it through `gnome.settings`.
- `launcher.hiddenEntries` replaces the catalog's default filename list. Only
  matching existing entries are hidden, with launch commands and associations
  preserved. It does not disable the underlying applications or services.
- `wallpaper.image` and `wallpaper.lockImage` accept paths or null. Shared images
  are declared in `flake.nix`; null leaves the corresponding image unmanaged.
  GNOME and DMS render them; bare Niri has no wallpaper renderer here.
- DMS `settings` and `session` map to their upstream options on NixOS and native
  JSON files on Arch. Nonempty declarations are read-only. To let DMS save its
  own settings, clear the corresponding declarations and disable managed
  wallpaper, which otherwise contributes values.
- `printing` provides CUPS and discovery; printer queues and drivers remain
  host-specific. `firmware` provides fwupd and GNOME Firmware; metadata refresh
  does not flash devices. `efiTools` only installs efibootmgr.
- `keyring` manages the password/certificate service. SSH stays with the chosen
  SSH agent. Arch greetd requires the [host PAM setup](hosts.md#arch-keyring-unlock).

Chinese input supports native Arch/NixOS desktops. It supplies Fcitx5 with
Rime Ice, one Rime entry, and English mode by default. Set
`features.chinese.englishByDefault = false;` for Chinese by default. Its `settings`
contains `inputMethod`, `globalOptions` and `addons`. Personal dictionaries stay
user-owned. GNOME uses Kimpanel; Niri retains Wayland input support. See the
[settings lifecycle](software.md#desktop-input-and-settings-lifecycle) for removal semantics.

## Applications

- `chrome.extensions` defaults to Bitwarden's Web Store ID. Set it to `[ ]` to
  stop declaring preinstalled extensions. Linux uses `normal_installed` policies;
  macOS uses External Extensions manifests and may request confirmation in Chrome.
  Linux HTTP/HTTPS/HTML associations can be overridden through
  `xdg.mimeApps.defaultApplications` in the host's Home Manager configuration.
- `vscode.settings` declares values restored on each activation while leaving
  the settings file writable. See [writable settings](software.md#writable-vs-code-settings)
  for merging, comments and removal behavior.
- `vim` uses the shared [vimrc](../nix/assets/vimrc) and pinned plugins. Native
  Vim and the Nix wrapper use the same configuration. Startup does not download
  plugins. Universal Ctags is supplied automatically for Tagbar through the selected
  software provider. `CodeFormat()` needs `astyle`; failures leave the buffer/file unchanged.
- `ghostty` uses [shared terminal settings](../nix/modules/home/features/ghostty.nix)
  with Darwin-specific additions. Its font dependency is supplied automatically.
- `mpv` configures ModernX and thumbfast. Nix uses the upstream wrapper; native
  players load script links. Linux desktop presets enable it. Darwin defaults
  to IINA, and explicitly enabling mpv there prefers Homebrew.

`devel` and `commonTools` are software groups defined in
[profiles.nix](../nix/lib/software/profiles.nix). Shared requirements are deduplicated.
Use `packageManager.extraPkg` for host-only extras and
`software.providerOverrides` for explicit source selection, or
`software.packageOverrides` for a managed application's custom Nix package.
The [port contract guide](ports.md) describes where platform implementations live.
Private Zsh settings belong in `~/.config/zsh/local.zsh`, outside the repository.
Smart cards and WSL device forwarding are covered in the
[smart-card guide](software.md#smart-cards).


## Shared feature presets

The host loader provides `profile` from
[`nix/lib/hosts/profiles.nix`](../nix/lib/hosts/profiles.nix).
All checked-in hosts use the same selection pattern:

```nix
{ profile, ... }:
{
  platform = "arch";
  features = profile.linuxDesktop // {
    efiTools.enable = true;
  };
  homeConfig = ./home.nix;
}
```

Presets are plain feature attribute sets. A `//` override replaces a top-level
group, so preserve the preset's nested group when changing only part of it.
For example, `desktop = profile.linuxDesktop.desktop // { gnome.enable = true; };`
adds GNOME without removing Niri or DMS. Hosts can request `lib` for standard
Nix attribute merging and module combinators. Feature options continue to be
evaluated by upstream `lib.evalModules`; the repository defines no separate
merge language.

Features contribute settings and requirements. Disabling one contribution does
not negate another feature's shared requirement. Use explicit upstream options
in `systemConfig` or `homeConfig` when overriding the resulting behavior; an
unsatisfied dependency is an evaluation error. Exclusive resources such as the
login screen use the declared desktop-stack priority instead of definition order.
