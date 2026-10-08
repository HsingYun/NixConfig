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
profiles = profile.linuxDesktop;
features = {
  desktop = {
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

## Desktop autostart

Configure `features.desktop.autostart` in the host entry point on NixOS or Arch.
It is disabled by default and has no default applications:

```nix
features.desktop.autostart = {
  enable = true;
  entries = {
    terminal.application = "terminal";
    browser.command = [ "google-chrome-stable" "--new-window" ];
    notes = {
      command = [ "/home/hsingyun/bin/open-notes" "work notes" ];
      environment.NOTES_MODE = "work";
      workingDirectory = "/home/hsingyun/Documents";
    };
  };
};
```

Each enabled entry specifies exactly one of `application` or `command`.
`application` selects the final `terminal`, `browser` or `fileManager` role;
the feature resolves its command, including the selected package provider.
An unavailable role is an error: select an application, provide a command or
disable the entry. This does not implicitly enable or install an application.
Explicit commands use an absolute executable path or the desktop session's
`PATH`. Arguments, including spaces, `$`, `%` and shell syntax, remain literal.
Invoke a script explicitly for shell logic. Environment values are also literal
and stored in the Nix store, so do not put secrets in them. A working directory
must be absolute and exist at startup; omitting it inherits the launcher directory.

Entries merge through the normal Nix module system. Use stable names and
`entries.<name>.enable = false` to disable an inherited entry. Names contain
letters, digits, `_`, `-` and `.` and cannot start with `.`. The host owns the
startup selection; entries apply to any XDG Autostart-capable desktop on it,
without desktop detection or session restrictions.

When replacing an inherited `application` with an explicit `command`, also set
`application = null` so the merged entry still selects exactly one command
source. Clear `command` in the same way when switching to an application role.

The feature resolves user intent into commands; a separate generic adapter
creates desktop files through Nixpkgs and links them through Home Manager's
`xdg.autostart`. That adapter knows no application roles or software providers.
Activation updates files without launching commands; the next desktop login
uses them. Removing an entry does not stop an already running process or
suppress an application's independently supplied startup entry. Keep one owner
for each application's startup. Input-method and desktop-shell services retain
their own lifecycle.

Niri has no default terminal startup. [NixOS-PC](../hosts/NixOS-PC/default.nix),
[ArchLinux](../hosts/ArchLinux/default.nix) and [NixOS-Pad](../hosts/NixOS-Pad/default.nix) explicitly declare
`features.desktop.autostart.entries.terminal.application = "terminal";`.
Disable that entry to retain terminal
shortcuts without opening a terminal at login.

## Application settings

Ghostty and MPV expose their native configuration structures through their
existing features. Settings do not enable a disabled feature:

```nix
profiles = profile.linuxDesktop;
features = {
  ghostty.settings = {
    font-size = 16;
    background-opacity = 1.0;
  };
  mpv = {
    settings = { hwdec = "auto-safe"; interpolation = false; };
    scriptOpts.osc.language = "eng";
  };
};
```

`ghostty.settings` maps to Home Manager's `programs.ghostty.settings`;
`mpv.settings` maps to `programs.mpv.config`, and `mpv.scriptOpts` maps to
`programs.mpv.scriptOpts`. Feature settings override the bundled application
defaults; upstream modules validate values and generate files. Unrelated defaults
remain intact. An exceptional conflicting low-level override can use `lib.mkForce`.

On Linux, Ghostty defaults to tabs integrated into the titlebar, places tabs
at the top, uses content-width tabs, and uses opaque toolbars with a subtle
separating border. These GTK defaults can be overridden through
`features.ghostty.settings`.

Niri's Qt theme and Electron Wayland preferences apply independently of Chinese
input. The Niri–Chinese integration owns input-method environment adjustments
and follows the configured locale; it only runs for an enabled Fcitx5 input method.
It copies `XMODIFIERS` only when present in the final Home Manager session
variables, preserving explicit removal of that variable.
Niri–MPV window rules also belong to the integration registry. Disabling either
feature removes that integration's contribution.

## Platform and application preferences

- `features.desktop.macos` is opt-in on Darwin. Its `settings` follow
  nix-darwin's `system.defaults` structure, including `finder`, `dock` and
  `NSGlobalDomain`; the Darwin adapter applies them. Configuring settings without
  enabling the feature has no effect.
- `features.wsl.usbip.enable` controls NixOS-WSL USB/IP integration. It is separate
  from smart-card support and is unavailable on other deployment platforms.
- `features.gpg.pinentry` selects an explicit Nix variant (`curses`, `tty`, `qt`
  or `mac`) through the software override mechanism. `null` retains the selected
  provider's default. The GPG feature must be enabled, and the chosen package
  must support the target platform. NixOS-WSL explicitly selects `curses`.
- `features.desktop.screenRotate.settings` configures the GNOME Screen Rotate
  extension. For example, Pad declares `orientation-offset = 1`; these settings
  disappear when the feature is disabled.
- `features.desktop.gnome.textEditor` configures GNOME Text Editor. Defaults
  enable `show-line-numbers`, set `tab-width = 32`, and disable `auto-indent`,
  `restore-session`, `spellcheck` and `wrap-text`. These are GNOME Text Editor
  preferences, not legacy Gedit preferences. For example, set
  `features.desktop.gnome.textEditor.tab-width = 8`; the feature validates the
  1–32 range and handles unsigned GSettings encoding internally.
  `features.desktop.gnome.settings` remains available for other dconf settings
  and explicit overrides of feature defaults.

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
user-owned. GNOME uses Kimpanel and selects the Fcitx GTK module at login,
replacing an inherited `GTK_IM_MODULE=ibus` (including the NixOS GNOME default)
to keep candidate windows positioned correctly. Other nonempty module selections
are preserved. Log out and back in after applying this change so desktop-launched
applications and user services receive the updated environment. Niri retains
Wayland input support. See the
[settings lifecycle](software.md#desktop-input-and-settings-lifecycle) for removal semantics.

## Applications

`homeConfig.desktop.applications` selects desktop roles independently of Niri.
`browser`, `terminal` and `fileManager` accept `null` (disable automatic integration)
or an attribute set with `command` (an argv list) and optional `desktopId`.
Only `fileManager` accepts `appId` (a window matching regex). Default selection is
policy: enabled Ghostty/Nautilus features supply defaults, and Chrome supplies a
browser default only on registered native Linux desktop platforms, not WSL.
Ghostty's final configuration enable switch also controls its default selection.
The terminal role also supplies `TERMINAL` on Darwin. Custom applications must be
installed separately. A terminal desktop ID enables the XDG terminal launcher by
default on Linux; that launcher's own enable switch requests its software through
the normal plan, even when no terminal feature or desktop compositor is enabled.

```nix
homeConfig.desktop.applications.browser = {
  command = [ "/usr/bin/microsoft-edge-stable" ];
  desktopId = "microsoft-edge.desktop";
};
```

Role fields use normal Nix submodule defaults. Overriding only `desktopId` or
`appId` preserves the default command and other fields; setting the entire role
to `null` disables its automatic integration. Changing `command` replaces the
argv list but retains other defaults. When selecting a different application,
set its desktop/window identifiers too, or explicitly set them to `null` to
remove the inherited MIME/terminal selection or window matching:

```nix
homeConfig.desktop.applications.fileManager.appId = null;
homeConfig.desktop.applications.terminal = {
  command = [ "/usr/bin/foot" ];
  desktopId = "foot.desktop";
};
```

The integrations use these roles for Niri application shortcuts/startup,
Linux MIME defaults and terminal selection, and GNOME's default favorites.
`TERMINAL` contains the selected executable's path (the resolved absolute path for
the built-in Ghostty default); Niri preserves the complete argv. This intentionally
replaces the former PATH-dependent `TERMINAL=ghostty` value.
Existing explicit `settings.binds` and `xdg.mimeApps.defaultApplications` overrides
still win. ArchLinux's existing Edge shortcut remains a host shortcut override,
so its existing Chrome MIME associations are preserved.

Default selection lives in `home/policies` and feature-scoped composition such
as `chrome-browser`. Desktop adapters consume roles without selecting a provider
or a specific application again. Niri-specific MPV window rules belong to the
Niri/MPV integration. Installing an application alone does not select a role.

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
  profiles = profile.linuxDesktop;
  features = {
    efiTools.enable = true;
  };
  stateVersion.home = "26.05";
}
```

Select a single preset with `profiles = profile.linuxDesktop;`, or a list with
`profiles = [ profile.cli myExtraPreset ];`. Host differences belong in `features`.
The entry point merges profile defaults at priority 950, between shared
`flake.nix` defaults (1000) and ordinary host definitions (100). Unsupported
platform defaults use priority 900. A feature-local provider selection, such as
`desktop.niri.shell`, enables its provider at priority 925: it overrides a
profile's default disable while preserving platform restrictions and explicit
host disables. Lower numbers are stronger in Nix.

Nested feature options retain unrelated profile definitions. Free-form settings
follow their declared types: overriding `desktop.niri.settings.layout.gaps` can
replace a weaker profile's entire `layout` value, while other settings keys and
the Niri enable flag remain intact. This is ordinary Nix option merging, not a
recursive attribute-update algorithm. A host list
replaces a weaker profile list, including when the host supplies `[]`; same-priority
profile lists concatenate. Conflicting profile scalars require a host override.
Use ordinary Nix module combinators for exceptional priority or ordering needs.
No manual `//` or recursive attribute merge is required at the host boundary.

Features contribute settings and requirements. Disabling one contribution does
not negate another feature's shared requirement. Use explicit upstream options
in `systemConfig` or `homeConfig` when overriding the resulting behavior; an
unsatisfied dependency is an evaluation error. Exclusive resources such as the
login screen use the declared desktop-stack priority instead of definition order.
