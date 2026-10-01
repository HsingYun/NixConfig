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

### Noctalia

`features.desktop.noctalia` provides Noctalia v5 on NixOS and Arch. It is disabled
in every shipped host and profile. The feature supplies the Niri system session;
enable `features.desktop.niri` as well for this repository's Niri configuration
and shortcuts. NixOS uses the locked Nixpkgs package and upstream modules. Arch
prefers the official `noctalia` package and reuses Home Manager's configuration
generator, then validates native configuration before linking it. Its session service uses the executable selected by the software
layer; `systemConfig.software.providerOverrides.noctalia = "nix";` explicitly
selects the Nix package instead.

```nix
features = profile.linuxDesktop // {
  desktop = profile.linuxDesktop.desktop // {
    niri = { enable = true; shell = "noctalia"; };
    noctalia.settings.theme.mode = "dark";
  };
};
```

DMS and Noctalia may both be enabled: their packages and settings coexist, while
`features.desktop.niri.shell` automatically enables the selected shell feature
and selects its session service and Niri shortcuts. The Niri feature must be
enabled; settings on a disabled feature have no activation effects. An explicit
`noctalia.enable = false` conflicts with selecting Noctalia and is rejected.
The default `shell = null` selects among independently enabled shell features.
Without an explicit selection, DMS has priority; when only Noctalia is enabled, it is
selected automatically. To remove DMS entirely, also set
`features.desktop.dms.enable = false;`. Final system/Home Manager options are
checked to reject autostarting different shells together. Custom manual launchers
and previously hand-enabled services remain outside this selection mechanism.

When Niri is the preferred desktop, Shell selection also pairs its greeter:
Noctalia uses Noctalia Greeter, DMS uses DMS Greeter, and bare Niri uses tuigreet.
The default session and shared lock wallpaper are passed to Noctalia Greeter.
NixOS uses the upstream `services.displayManager.noctalia-greeter` module. Arch
installs `noctalia-greeter` from AUR through yay, along with
AccountsService, Polkit and bubblewrap, and manages its configuration through the existing
login-manager activation. The declarative TOML file is exposed read-only inside
the greeter process's mount namespace; the package's original configuration and mutable
`sync.toml` remain untouched. The login daemon and resulting desktop session
keep the host filesystem view. Arch requires unprivileged user namespaces for
this configuration view; activation checks the greeter account before changing
the login manager. Its native package supplies the compositor libraries,
Polkit policy, setup hooks and session wrapper; forcing its Arch provider to Nix
is rejected. The Noctalia Shell package itself can still use the Nix provider.
Greeter settings and arguments are exposed through
`systemConfig.services.displayManager.noctalia-greeter.{settings,extraArgs}`.

GNOME can remain installed as another login session; if it is the preferred
desktop, GDM owns login and neither graphical greetd greeter starts. The shell
service starts with `niri.service` and is conditioned on the Niri desktop
environment. Explicit system overrides can choose another greeter, but enabling
two graphical greeters is rejected.

`features.desktop.noctalia.settings` maps to upstream `programs.noctalia.settings`.
Home Manager writes the base `noctalia/config.toml`; Noctalia's own runtime state
can override base settings according to its upstream configuration rules.
Desktop and lock images use the shared wallpaper feature. Noctalia-specific
settings remain available through `homeConfig.programs.noctalia`.

GNOME hosts can set
`features.desktop.gnome.settings."org/gnome/desktop/interface".clock-show-seconds = true;`.
`screenRotate` requires GNOME; sensor offsets and touchscreen calibration belong
to the individual host. NixOS-Pad contains the Pocket 4-specific values.

Niri provides `Mod+D` / `Mod+Tab` for overview and `Mod+T` for Ghostty when its
feature is enabled. It skips the startup hotkey overlay and leaves keyboard
layout selection to the system unless a host explicitly overrides it.
With DMS running, `Mod+M` / `Ctrl+Alt+Delete` opens its task
manager. DMS defaults to a dynamic theme, blur
(including overview wallpaper blur), the date format `M 月 dd 日`, and the app
drawer's list view. Override these through `features.desktop.dms.settings`.
DMS also installs and uses Maple Mono NF CN for monospace text. Its launcher
uses the OS logo; its visible Dock groups applications, uses line indicators,
isolates applications by display, and includes an OS-logo launcher. Active apps
use the success color. The standard status bar includes network throughput.
Monitor names, modes, scale, positions and monitor-specific DMS preferences
belong exclusively in host definitions. Shared features do not select hardware.
For example, ArchLinux sets `desktop.dms.settings.matugenTargetMonitor = "DP-5"`
alongside its dual-monitor Niri configuration.

Without runtime fragments, Niri defaults use ordinary Home Manager settings:
overriding one touchpad field retains the other feature defaults, and `mkForce`
can replace the declared settings. Ordered default rules precede host rules.
The shared Niri adapter owns this policy; integrations register their
application-owned fragments, merge semantics and affected default sections.
Only those sections move into fallback includes. A runtime layout fragment,
for example, does not change touchpad defaults or their Nix merge behavior.

When Niri and DMS run together, the optional upstream `enableDefaultConfig`
include loads first, then an immutable feature-defaults include,
followed by writable DMS fragments from `$XDG_CONFIG_HOME/niri/dms`,
then the explicit settings generated by the official Home Manager module.
Host settings therefore override dynamic colors, layout, cursor, input and
window rules. Default shortcuts remain declaratively managed. DMS outputs load
last because Niri uses the first matching output: a host declaration owns the
entire output block, and DMS can configure other displays. Niri also replaces
whole mouse/touchpad blocks across includes; in this layered mode a host
declaring one owns all settings in that block, including omitted values
reverting to Niri defaults. Missing dynamic
fragments are allowed; malformed existing fragments remain errors.

## Configuration ownership and precedence

All platforms use the same rules. Package providers only select installation
and executable paths; they must not change configuration ownership.

Two independent mechanisms must not be confused:

- **Nix definitions:** feature values use `lib.mkDefault`; normal host definitions
  override them. `lib.mkForce` is an explicit escape hatch. List composition uses
  the option's declared type. This follows the upstream module system.
- **Application loading:** the application's parser determines whether keys,
  blocks, rules or whole files merge, replace, or accumulate. Nix definition
  priority does not control GUI-written files or application include order.

Each adapter must choose and document ownership at the smallest unit its
application actually supports:

| Mode | Owner and activation behavior |
| --- | --- |
| Declarative | The upstream NixOS/HM module owns the declared values or file. Activation applies the declaration. GUI changes have no promised persistence. |
| Runtime | The application owns the writable file. HM does not generate or replace it. A feature being enabled alone does not authorize overwriting it. |
| Layered | Only when the application supports it: feature fallback defaults, explicitly allowed runtime preferences, then host declarations in semantic precedence. Generated and writable files have separate owners. |

Layered precedence is **explicit declaration > runtime preference > fallback**.
This is not a blanket rule allowing GUI changes to override declarative feature
values. For example, an HM-managed DMS settings JSON is declarative even though
DMS-generated Niri fragments are runtime layers; GNOME dconf continues to apply
declared values through the official module.

The business-independent `nix/assets/helpers/common/config-layers.nix` orders
serialized fragments for `last-wins` and `first-wins` parsers using standard Nix
module ordering. It validates adapter-supplied ordering positions rather than
assuming that upstream modules share a universal order. It does not parse
application data, write user files, or infer ownership from filenames.
Adapters supply positions compatible with all upstream includes, rendering,
the merge strategy and ownership unit. Whole-block replacement gives the winning layer the whole block;
an append-only format needs explicit application-specific conflict handling and
must not be described as field-level merging. Formats without layered loading
must use declarative or runtime ownership instead.

Feature integrations must check the final upstream enable options before adding
dependent startup commands or shortcuts. Commands must use the selected software
provider and declare their installation dependency. Tests should exercise actual
parser results for conflicting layers, missing/malformed runtime data, partial
host overrides, upstream default configurations, final disable overrides and
fresh-install dependencies, rather than only inspecting generated text order.

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
  GNOME, DMS and Noctalia render them; bare Niri has no wallpaper renderer here.
- DMS `settings` and `session` map to their upstream options on NixOS and native
  JSON files on Arch. Nonempty declarations are read-only. To let DMS save its
  own settings, set `homeConfig.programs.dank-material-shell.settings = lib.mkForce { };`
  (and likewise `session` for writable session state). This explicitly removes
  feature defaults and managed wallpaper values from that file.
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
