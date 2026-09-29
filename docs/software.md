# Software providers and feature ownership

Hosts select `platform`, `packageManager`, and `features`. Software identities, package names, provider fallback, runtime paths, and installation manifests belong to the shared software layer. Hosts normally do not set `programs.*.package`; host-specific tools use the selected manager's native names in `externalPkg`.

Feature input is a tree: `features.desktop.niri.enable`, `features.desktop.keyring.enable`, and `features.chrome.extensions` are examples. Feature catalog entries retain stable internal IDs for dependency and integration references. Their optional `path` declares the public path (otherwise `[name]`); `.enable` is always a boolean. Additional `options` declare a default, validation function, and description. `defaultPlatforms` narrows where a default-enabled feature is enabled without narrowing its supported platforms. `defaultFrom` enables a feature by default when any listed feature is enabled; an explicit setting still wins. The catalog rejects invalid defaults, overlapping option paths, unknown references, and dependency/default cycles.

Shared and host input is validated against this schema and merged recursively at the field level. Explicit null values override inherited image paths. Lists replace inherited lists, including `[]`. Configuring an option does not implicitly enable its feature. The resolved tree is passed to Home Manager as read-only `config.features`; hosts configure it in `default.nix`, while `home.nix` retains upstream module settings and package overrides.

`homeModulesByPlatform` and `activationByPlatform` select module adapters and dependency activation paths through catalog metadata. Choice rules can restrict their `platforms`; desktop/login choices apply to Arch and native NixOS. The generic resolver does not branch on GNOME, Niri, DMS, wallpaper or launcher identities. Desktop settings use `desktop.gnome.settings` (dconf), `desktop.niri.settings` (KDL), `desktop.dms.settings/session` (JSON), `desktop.wallpaper.image/lockImage`, and `desktop.launcher.hiddenEntries`. Business defaults and rendering remain in their modules.

Arch desktop features require pacman. The DMS adapter manages JSON and native service symlinks because the upstream HM module unconditionally installs its Nix runtime. It enables Arch's service only for Niri, preserving the package's DBus notification service and restart behavior. Native GNOME extensions are enabled by UUID rather than copied into the Nix profile. The GNOME feature explicitly requests the selected Arch desktop packages, including GDM, rather than a pacman package group. Arch and NixOS share `preferences.desktop` and `preferences.loginManager`: GNOME supplies GDM, while Niri or DMS supplies greetd. Multiple candidates require explicit selection. DMS supplies the greetd UI; bare Niri uses tuigreet. After package installation and file linking, native activation installs dedicated greetd configuration when selected, enables the chosen login manager using sudo, and sets graphical.target as the default boot target. The greetd drop-in reads `/etc/greetd/nixconfig.toml`, preserving the original host configuration. It installs the new display-manager alias before disabling the previous manager’s boot links, without stopping services or using --now. Repeated activation is a no-op when the boot configuration matches. On Arch, choosing `none` or disabling the desktop features relinquishes management without tearing down the existing login service. GNOME requests its own portal and keyring packages even without Niri; the keyring feature independently controls the user units. Launcher rules inspect native entries at activation time; on Arch, both Nix and native sources use one activation-owned override per filename, so a provider change does not collide with HM link preflight. A checksum manifest permits cleanup without overwriting or deleting user-owned edits. NixOS instead uses declarative Home Manager links to the filtered build output; its launcher adapter does not scan native paths at activation.

## Layers

1. **Features** declare software identities and capability requirements, then configure applications using the resolved software.
2. **Definitions**: `profiles.nix` defines the base, user, and devel groups and their Nix/Homebrew/pacman mappings. `catalog.nix` combines these groups with application definitions and shared dependencies. `recipes.nix` provides recipe constructors.
3. **Resolution** (`resolve.nix`) merges requests, expands dependencies, checks platform support and capabilities, selects a provider, and matches extras to software identities. Its shared installation planner reconciles extras against confirmed installation owners.
4. **Providers** (`providers.nix`) define supported platforms, fallback order, recipe validation, package identity, command paths, and installation plan formats.
5. **Runtime planning** (`materialize.nix`) incorporates final packages produced by upstream modules, finalizes extra ownership, and computes runtime paths. Feature `software.bindings` connect software identities to upstream package and enable options. `nix-packages.nix` handles output selection and package priorities shared by installation and runtime planning.
6. **Installation backends** consume the plan through Home Manager, NixOS/nix-darwin, Homebrew declarations, or pacman/yay commands during Home Manager activation.

The managed user's `software.plan` is the common plan for both user and system backends. They do not resolve providers independently. Base tools and optional features use the same resolution process; shared profile entries reuse the same recipe.

NixOS continues to manage kernels, drivers, system services, and upstream modules' internal dependencies. This layer coordinates the user software and tools explicitly managed by this repository.

## Hosts and default providers

```nix
{
  platform = "darwin";
  packageManager = "homebrew";
  features = {
    ghostty.enable = true;
    vim.enable = true;
    git.enable = true;
    chrome.enable = true;
  };
}
```

- `nixos` and `nixos-wsl` default to Nix.
- `darwin` defaults to Homebrew and falls back to Nix when necessary.
- `arch` hosts default to pacman, preferring native packages and falling back to Nix when a recipe is missing, unavailable, or lacks a required capability.
- Unimplemented managers such as `apt` fail evaluation. Implemented managers also reject unsupported platforms, such as pacman on NixOS.

Resolution uses the catalog, target platform, and declared capabilities. It does not inspect installed packages or query remote repositories during evaluation. A native installation failure does not trigger fallback to another provider.

Homebrew itself supports Linux, but this repository currently connects its Homebrew backend only through nix-darwin. Linux support would require a separate activation backend, prefix handling, and platform-specific recipe availability.

## Extra packages

The shorthand `packageManager = "homebrew";` is equivalent to `{ type = "homebrew"; externalPkg = { }; }`. Use the structured form for extras:

```nix
packageManager = {
  type = "homebrew";
  externalPkg = {
    brews = [ "aria2" "rsync" ];
    casks = [ "coteditor" ];
  };
};
```

Arch distinguishes repository packages from AUR packages:

```nix
packageManager = {
  type = "pacman";
  externalPkg = {
    packages = [ "rsync" ];
    aur = [ "google-chrome" ];
  };
};
features = { devel.enable = true; ghostty.enable = true; };
```

The Nix backend accepts attribute paths, for example `externalPkg.packages = [ "aria2" "llvmPackages.clang" ];`. Unknown fields, invalid names, and unsupported managers fail evaluation.

Extras that match active software identities follow those identities' selected providers, overrides, and wrappers. For example, the GPG agent integration requires Nix store packages, so an extra Brew `gnupg` request is satisfied by that integration instead of installing another copy through Brew. If no feature or base requirement requests that identity, the extra remains an independent installation request. Extras do not enable feature configuration.

The same rule prevents an extra `mpv` request from installing an unconfigured player alongside Home Manager's configured wrapper. An explicit Nix output, such as `llvmPackages.llvm.dev`, is also reconciled when an active recipe already provides it. Requesting the same pacman package from both a repository and AUR is rejected.

Darwin, Arch, PC, and Pad enable `features.commonTools.enable` for aria2, GnuPG, GnuTLS, Graphviz, ncurses, OpenSSL, pinentry, rsync, SQLite, xz, zlib and zstd. These requirements prefer the selected manager and fall back to Nix when needed. GnuPG and pinentry reuse existing identities: enabling GPG merges its store-package requirements, preventing duplicate native installations. Disabling commonTools removes only its requests. Platform differences remain in `externalPkg`: procps on Linux, pinentry-curses on NixOS, and watch and generic pinentry on Darwin.

## Development tools

The `devel` feature includes Git, LLVM/Clang, LLDB, CMake, Ninja, Meson, Autotools, binary inspection tools, Python, coreutils, Abseil, GCC, GDB, Git LFS, Go, Node.js, OpenJDK, Protobuf, Rust/Cargo, TypeScript, and Telnet.

These tools are defined centrally rather than repeated in host extras. Darwin, Arch, PC, and Pad enable `devel`. With Nix, GCC and Clang coexist, with Clang providing the default `cc` and `c++` commands unless package priorities are explicitly changed.

Some mappings differ across providers:

| Software | Nix attribute | Homebrew formula | pacman package |
| --- | --- | --- | --- |
| Abseil | `abseil-cpp` | `abseil` | `abseil-cpp` |
| Node.js | `nodejs` | `node` | `nodejs` |
| OpenJDK | `jdk` | `openjdk` | `jdk-openjdk` |
| Telnet | `inetutils` | `telnet` | `inetutils` |
| Rust and Cargo | `rustc`, `cargo` | `rust` | `rust` |

Rust and Cargo are separate software identities but share one native package installation. Brew's LLVM formula also supplies clang-format, so no separate formula is needed.

## Package overrides and outputs

Override a feature's package in the host's Home Manager configuration:

```nix
{ pkgs, ... }:
{
  software.packageOverrides.pinentry = pkgs.pinentry-tty;
}
```

An override forces Nix selection for that identity and updates its installation plan, runtime paths, and upstream module defaults. It does not enable software that has no active requirement. Directly assigning a different package to an active bound upstream option fails with a message pointing to this override interface. Upstream constraints still apply, including Home Manager's restrictions on custom mpv packages when scripts require wrapping.

Recipes declare required outputs by name rather than storing a second list of derivations:

```nix
llvm.nix = nix pkgs.llvmPackages.llvm // {
  outputs = [ "out" "dev" ];
};
```

Overriding LLVM preserves this rule and selects `out` and `dev` from the replacement package. This keeps `llvm-config` available without accidentally retaining the old package's `dev` output. A replacement missing a required output fails explicitly. Each selected output preserves the package's `meta.priority`. Recipes without an explicit output list retain normal Nix output-selection behavior.

On NixOS, the shell feature also connects `programs.zsh.package` and the managed user's login shell to the selected Zsh package. A conflicting system-level package assignment is rejected while the system Zsh module is enabled. nix-darwin's upstream Zsh module has a different interface and does not expose this NixOS package option.

On every supported platform, the shell feature loads `$HOME/.config/zsh/local.zsh` at shell startup if it is readable, after the normal Zsh initialization (`initContent` order 1500). Keep private aliases, environment variables, and machine-specific initialization in this local file. Home Manager does not create, copy, or manage it, and its contents are not included in the repository or the Nix store. Missing files are skipped. Avoid repeating the Oh My Zsh initialization already managed by the feature.

## Runtime paths and priorities

Managed Nix executables take precedence over native provider paths, protecting selected Nix commands from stale native installations. Native feature paths precede independent native extras.

Within the Nix portion of PATH, outputs are ordered by `meta.priority`, using the same convention as Nix profile assembly: smaller numbers take precedence. Runtime planning includes required outputs and final upstream wrappers, so software identity names do not determine which compiler or other overlapping command runs.

Extras are deduplicated only against confirmed installations: native selections, centrally installed Nix packages, or active upstream runtime packages. If a module-owned program is disabled, an explicit matching extra remains in its requested provider's installation plan and is reported as `external`. For example, disabling `programs.mpv.enable` while keeping an `mpv` extra installs the ordinary package without the feature's wrapper. A resource-only request without a confirmed installer does not absorb an explicit extra.

Independent Nix extras receive a lower priority than selected software, including final wrappers whose priority differs from their input package. The adjusted priority is used both in profile assembly and in the generated PATH. Unique commands from those extras remain available. Equal-priority packages with conflicting files are still subject to normal Nix profile collision checks.

Packages from nixpkgs and custom Nix derivations use the same mechanism when supplied through the software layer. Arbitrary `home.packages` entries and manually configured shell paths are outside its ownership model.

## pacman and AUR activation

A pacman recipe uses `type = "package"` for an official repository package or `type = "aur"` for an AUR package. Both belong to the same native backend. For example, `pacman = aur "google-chrome";` still produces a resolved identity with provider, package name, capabilities, and selection reason.

The Maple Mono AUR names are `maplemono-nf-cn` and `maplemono-ttf`, as documented upstream. They differ from ArchLinuxCN's `ttf-maplemono-*` names.

Home Manager installs native packages after the write boundary and before linking the new configuration:

1. Query the pacman database and select packages that are not installed. Existing packages are not automatically upgraded.
2. Validate prerequisites before the first installation, then run `/usr/bin/sudo /usr/bin/pacman -S --needed` for repository packages.
3. Run `/usr/bin/yay -S --needed --aur` as the Home Manager user, preserving normal interaction and rejecting root AUR builds.
4. Include `base-devel` and Git when AUR packages are requested. The user must install yay beforehand; activation fails clearly if it is required but missing.

Home Manager dry-run skips installation and does not require the target tools to exist. Installation failures stop activation and preserve the failing exit status. The backend does not run `-Sy`, perform a full system upgrade, remove unrequested packages, or clean AUR build dependencies. Maintain Arch through normal system upgrades; if stale repository metadata prevents installation, update the system before activating again.

Native installations are not rolled back with Nix generations, and successful native installation steps are not undone if a later activation step fails.

References: [pacman manual](https://man.archlinux.org/man/pacman.8.en), [yay manual](https://github.com/Jguer/yay/blob/next/doc/yay.8), [Maple Mono installation guide](https://github.com/subframe7536/maple-font/tree/v7#arch-linux).

## Feature author interface

```nix
{ lib, software, ... }:
{
  software.requirements.git = { };
  software.bindings.git = {
    packageOption = [ "programs" "git" "package" ];
    enableOption = [ "programs" "git" "enable" ];
  };
  programs.git = {
    enable = lib.mkDefault true;
    package = lib.mkDefault software.git.package;
    settings.alias.st = "status";
  };
}
```

`requirements` declares software needs, capabilities, installation scopes, and installation responsibility. The `software` module argument exposes the resolved identities:

- `provider`: selected backend.
- `package`: the Nix package passed to an upstream module, or `null` for native software.
- `runtimePackage`: the actual Nix executable package, including an upstream wrapper when applicable; `null` for native software or an inactive module-owned program.
- `runtimeOutputs`: the selected Nix runtime outputs used to generate paths.
- `command "executable"`: the executable's path in its runtime package or native provider's configured command directory. Requesting a command from an inactive module-owned Nix program fails explicitly.
- `providedCapabilities`: capabilities supplied by the selected recipe.
- `reason`: preferred provider, explicit override, or the reason for fallback.

Applications whose Home Manager modules accept `package = null` can use native installations directly. Modules requiring a Nix package path must declare that requirement:

```nix
software.requirements.zsh.capabilities = [ "store-package" ];
```

Zsh, GPG agent/pinentry, nh, and mpv script resources currently have this requirement. Git, Vim, Ghostty, commonTools and ordinary development tools can prefer native providers. On Arch, mpv itself uses pacman with `programs.mpv.package = null`; HM generates configuration, links the pinned scripts into the user scripts directory, and installs their font resources in the profile. The Nix wrapper remains active for NixOS/macOS or an explicit Nix override.

`bindings` connects a software identity to an upstream configuration option. `packageOption = [ "programs" "gpg" "package" ];` refers to `config.programs.gpg.package`, not a filesystem path. The binding validates package consistency and reads the runtime package; the feature still assigns the upstream package default.

`enableOption` identifies the upstream boolean enable option. A disabled adapter neither validates its package assignment nor reads an undefined final package. Omitting `enableOption` treats the adapter as always active. Disabling an upstream module does not remove the feature's requirements: centrally installed packages remain installed until their requests are removed.

Set `installNix = false` when an upstream module installs the configured program or loads a package as a resource. For a wrapped executable, set `runtimePackageOption = [ "programs" "mpv" "finalPackage" ];` so runtime planning uses the wrapper. Disabling that module removes its runtime package and PATH contribution; it does not cause the central installer to install the unwrapped input instead. Resource-only plugins do not contribute executable paths.

`scopes` selects `home` or `system`, defaulting to `home`. Dependencies inherit their requesters' scopes. Standalone Home Manager rejects system-scoped Nix installation requests.

For software that needs no additional configuration, declare a package-only feature in the catalog:

```nix
chrome = {
  platforms = all;
  software = [ "chrome" ];
};
```

Shared module requirements merge, with capability requirements combined. Ghostty declares Maple Mono as a dependency; the Chinese feature can request the same font without a duplicate installation. The `font` capability enables Home Manager fontconfig for selected Nix fonts; native providers install native fonts themselves.

## Homebrew path metadata

`binDirs` lists subdirectories to add to PATH, relative to the formula's `opt/<name>` directory. Its default is `[ "bin" ]`, and list order is preserved.

`commandDir` selects the single subdirectory used by `command "executable"`. It defaults to `"bin"` and does not search `binDirs` or rename executables.

For example, coreutils uses `libexec/gnubin` for ordinary command names such as `ls`, while also adding its `bin` directory to PATH. Python adds both `libexec/bin` and `bin`: the former contains unversioned aliases such as `python`, while `command "python3"` points to `bin/python3`.

## Maintenance features

`features.efiTools.enable = true;` requests `efibootmgr`. It is disabled by default and supported on native NixOS and Arch. It does not change boot loader configuration or modify EFI variables automatically.

NixOS installs it into the system environment. Arch uses the selected backend: pacman installs the native package, while Nix installs it into the user environment. Base tools do not request it implicitly. NixOS-Pad enables it based on its existing EFI configuration; PC and Arch leave it disabled until selected by their hosts.

`features.desktop.screenRotate` requires an active GNOME desktop. Dependencies are checked against actual module activation, allowing a dependency supplied through host configuration as well as through a feature.

## Smart cards

`features.smartcard.enable` is enabled by default on NixOS, NixOS-WSL, and Darwin. It integrates the platform's smart-card transport without enabling GPG on its own; `gpg` and `gpg.sshSupport` remain separate features.

- On NixOS and WSL, it enables `services.pcscd`. The GPG integration uses PC/SC whenever that service and the Home Manager GPG module are enabled, including when another system module provides the service.
- On Arch, explicitly enabling the feature requests native `pcsclite`, `ccid`, and `polkit`, manages `pcscd.socket`, and selects PC/SC when GPG is enabled. There is no hardcoded host library path: Nix GnuPG uses its own compatible PC/SC client library with the native daemon.
- On Darwin, macOS owns the native smart-card service. When the feature and the Home Manager GPG module are enabled, it sets `disable-ccid` in `scdaemon.conf` to select PC/SC. GnuPG already defaults to Apple's PC/SC framework, so no explicit driver path or additional daemon is installed. Local scdaemon overrides remain possible.

`features.smartcard.allowBackgroundAccess` defaults to false. Enable it explicitly for an account that needs PC/SC outside an active desktop session (for example Arch-WSL or SSH). Linux adapters grant only `org.debian.pcsc-lite.access_pcsc` and `access_card` to that account. Arch installs an owned Polkit rule using sudo, and removes it when disabled only if its recorded file identity and checksum are unchanged; an administrator-edited file is preserved and reported as a conflict. NixOS uses `security.polkit.extraConfig`. Darwin rejects this Linux-only option. The [Arch-WSL host guide](hosts.md#arch-under-wsl) opts in; ordinary Arch does not. See [ArchWiki GnuPG](https://wiki.archlinux.org/title/GnuPG#Using_a_smart_card_on_a_remote_client).

Disabling the feature on Darwin removes this repository's scdaemon setting; it does not disable macOS smart-card support. This feature does not configure macOS login or FileVault authentication, pair a card with an account, or provision keys. WSL still requires the device to be made available to the guest.

After activation, connect the device and check it with `gpg --card-status`. If an existing scdaemon process still uses the old settings, run `gpgconf --kill scdaemon` before checking again. Configuration tests cover feature toggles, externally enabled GPG, disabled GPG modules, and local overrides; actual card access requires validation with the user's hardware.

References: [Apple smart-card integration](https://support.apple.com/guide/deployment/intro-to-smart-card-integration-depd0b888248/1/web/1.0), [GnuPG scdaemon options](https://www.gnupg.org/documentation/manuals/gnupg/Scdaemon-Options.html).

## Disabling features

Disabling a feature removes its configuration and software requests. Packages still required by another feature or by base configuration remain. Niri launches terminals through `xdg-terminal-exec`; enable `ghostty` explicitly when desired.

For Nix, removing the final request removes the package from the managed profile. Homebrew keeps `cleanup = "none"`: removing a manifest entry does not uninstall existing software or delete data. pacman/yay likewise installs missing packages without removing packages dropped from the manifest. Explicit Nix application overrides on Arch are the exception: after the Nix installer succeeds, the adapter removes matching installed pacman/AUR packages using plain `pacman -R --noconfirm`. Current native requirements are excluded. Account login shells and native active/enabled system services are checked before removal. Reverse dependencies make the transaction fail; recursive/cascading removal and dependency bypass are never used. Mere feature removal and implicit capability fallback do not trigger removal.

## Desktop input and settings lifecycle

The Chinese feature supports native Linux desktops only. Its common module owns structured Fcitx profile files and the two Rime preset patches; adapters select NixOS's HM runtime or native Arch Fcitx/Rime/GTK/Qt packages. The Arch autostart adapter keeps its owned Hidden entry after feature removal, preventing the retained package from restarting Fcitx at the next login; never-enabled configurations are untouched. The local working setup is represented as one Rime entry and English mode by default, without copying learned dictionaries or monitor-specific settings. GNOME integration applies to both distributions. WSL hosts use CLI tools and terminal pinentry without Fcitx or graphical-session dependencies.

Keyring and compositor packages are OS-bound resources. Arch adapters reject unsupported Nix overrides rather than silently dropping native dependencies. NixOS's upstream keyring module has no package option, so package customization uses a system overlay; a mismatched home-only override is rejected. Standalone Nix keyring validates the absence of NixOS wrapper paths.

The shared dconf adapter replaces key-only cleanup with value tracking. It runs even with an empty desired database, restoring original values only if the current value still matches the last managed write. It preserves external edits. A legacy HM default database is adopted from the old generation's immutable INI input and key list; unknown legacy original values reset to schema defaults only when unchanged. Named databases written by this adapter follow the same lifecycle.

Default login sessions are used by tuigreet explicitly. The DMS greeter seeds its session memory once per changed default while retaining the remembered username and later interactive session selections. GNOME as the default with greetd uses tuigreet; Niri with DMS uses the DMS greeter.

## Native system services

`features.desktop.printing` and `features.desktop.firmware` are independent features on Arch and native NixOS, default-enabled by GNOME/Niri/DMS. The NixOS adapters use `services.printing`, Avahi, and `services.fwupd`; GNOME may retain its own Avahi requirement when printing is disabled. Arch requests native host packages and declares required units through `nativeSystemd.units`. Multiple modules' lists merge and deduplicate. The desktop-session adapter also supplies NetworkManager/Bluetooth and native audio, power and file services. HM manages PipeWire/WirePlumber user units. A preflight rejects competing active network managers before mutations. `nativeSystemd.enableOnly` tracks boot-time units such as NetworkManager-wait-online without starting them during activation. Printing requests `cups.socket` and both Avahi units; smart cards request `pcscd.socket`; firmware requests only `fwupd-refresh.timer`, while the firmware daemon remains DBus-activated. The timer refreshes metadata, not device firmware. See [ArchWiki CUPS](https://wiki.archlinux.org/title/CUPS) and [fwupd](https://wiki.archlinux.org/title/Fwupd).

The adapter runs after package installation and file linking, including when the last service feature is removed or the package manager changes. Its root-owned state records each account's desired units, initial enablement/activity, and symlinks created by enable operations. All unit states are recorded before mutations, including `Also=` peers. It journals enable operations before changing links and uses an exclusive lock and atomic state writes for retries. Multiple accounts share references to units. Cleanup removes only unchanged owned links, reloads systemd, and stops originally inactive/disabled units with no remaining external boot links. Existing enabled/active units, edited links, and native packages remain intact. It never masks a unit or turns off DBus activation.

Display managers use a separate adapter because changing them must not terminate a graphical session. GDM/greetd switching updates boot configuration without `--now`, and retries check both services even after the alias has already changed. Selecting `none` relinquishes login management and preserves the current login path.

Reusable activation code is kept in `nix/assets/helpers/`. Feature modules declare capabilities and requirements; platform adapters translate them into native requests. Native service tests cover repeated apply, last-owner removal, shared accounts, pre-existing services, `Also=`, edited links, masked units, and failures during enable/reload/stop. These are controlled systemctl simulations, not hardware tests.

## Inspecting plans

```sh
nix eval --json .#lib.softwarePlans.Darwin
nix eval --json .#lib.softwarePlans.NixOS-Pad
nix eval --json .#lib.softwareManifests.Darwin
nix eval --json .#lib.softwareManifests.ArchLinux
```

`softwarePlans` reports providers, capabilities, scopes, selection reasons, and runtime packages. `softwareManifests` reports the manager, extras, and combined Nix/Homebrew/pacman/AUR installation lists. `externalReport` identifies independent extras and requests satisfied by feature identities. `nix.delegated` lists programs installed by upstream modules.

## Adding providers

A new provider needs:

1. Platform support, fallback rules, recipe validation, package identity comparison, resolution, and plan generation in `providers.nix`.
2. Package mappings and capabilities in the software catalog.
3. An installation backend connected to its supported platforms.
4. Tests for installation, duplicate requests, removal of requests, and failure handling.

Native backends must define activation timing, privilege requirements, and handling of existing software. Features and the common resolver should not acquire provider-specific branches such as `isPacman`.

## Validation

Tests cover provider preference, missing/unavailable/incapable-provider fallback, shared dependencies, feature removal, scopes, invalid catalogs and managers, dependency cycles, Homebrew integration, and Home Manager adapters.

Software consistency regressions cover package overrides, required outputs, output priorities, inactive bindings, and system/user Zsh ownership. Runtime tests use small executable packages with real Home Manager modules and Nix profiles to verify mpv wrapping, stale native commands, compiler priority overrides, and extras alongside final wrappers. Linux's devel test builds C/C++ examples using real toolchains.

pacman/yay activation tests use substitute commands to verify installation order, already-installed packages, dry-run, prerequisite checks, and failure propagation. They do not invoke real sudo or install native packages.


## Platform and mutation boundaries

[`hosts/platforms.nix`](../nix/lib/hosts/platforms.nix) is the shared deployment
platform registry for host construction, feature validation and software
providers. `arch` is distribution-specific; Nix systems such as `x86_64-linux`
remain CPU/OS targets. Shared experience presets belong to the host library,
while `hosts/` contains only actual machines. See [Creating hosts](hosts.md).

NixOS and Darwin use their upstream system/Home Manager modules. Arch's system
service, policy, input-autostart and native-package adapters are loaded through
its platform entry point. Arch-specific service requirements are not copied
into NixOS or Darwin activations. The shared dconf adapter still expresses a
declarative target for mutable user settings, with value-aware restoration when
the target is removed; it does not edit NixOS system configuration.

Native recipes list applications and capabilities explicitly requested by this
configuration. Pacman/yay resolve their current dependency graph, providers,
versions and conflicts at transaction time. Removal uses plain `pacman -R`,
without recursive removal or dependency bypass. This repository does not pin or
reimplement Arch's dependency graph. Unit activation uses the installed systemd
unit definitions; dependencies and `Also=` peers outside the explicitly managed
unit set are not claimed for automatic cleanup. Before stopping a retired unit, the adapter checks the current reverse dependency graph and preserves units with active consumers outside the retiring set.

Privileged file changes for Chrome, smart cards and greetd share one ownership
protocol under `/var/lib/nixconfig/files/`. It uses root-owned records, per-file
locks, staged atomic writes, content checksums and inode identity. Interrupted
writes retain enough information for retry without adopting an unrelated file
with matching bytes. Different configuration owners may share identical policy;
conflicting policy is rejected, and one owner cannot delete another's file.
Files and parent directories containing symlinks, special files, unmanaged
files and externally replaced/edited files are conflicts. Existing untracked
files are never adopted merely because their content matches. Unknown display
managers are not disabled automatically.

The low-level file operations are shared by activation helpers under
`nix/assets/helpers/`. They open parent directories without following symlinks,
use temporary files in the destination directory, and recheck managed content
before deletion. Application data, personal dictionaries and unrelated files
are outside these tools' cleanup scope. Activations are retryable rather than
an atomic transaction across the whole Arch system; a failure can leave earlier
successful changes applied. Inspect the reported conflict and retry instead of
removing entire configuration directories.
