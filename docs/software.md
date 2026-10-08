# Software providers and feature ownership

Hosts select `platform`, `packageManager`, and `features`. Software identities, package names, provider fallback, runtime paths, and installation manifests belong to the shared software layer. Hosts normally do not set `programs.*.package`; host-specific tools use explicit provider groups in `extraPkg`, including packages absent from the identity catalog.

A host-only customization must keep its configuration, extra packages, and any
required Nix license exceptions in that host. It does not justify adding a recipe
or permission to shared features or defaults. ArchLinux's Edge shortcut, for
example, uses an AUR package declared by that host; it needs no nixpkgs license
exception. A host choosing an unfree Nix package must declare its own narrow
`nixpkgs.config.allowUnfreePredicate` in the owning Home Manager or system module.
That predicate replaces the shared default, so it must also allow the unfree
packages used by that host's enabled features.

Feature input is a tree: `features.desktop.niri.enable`, `features.desktop.keyring.enable`, and `features.chrome.extensions` are examples. Feature catalog entries retain stable internal IDs for dependency and integration references. Their optional `path` declares the public path (otherwise `[name]`); `.enable` is always a boolean. Additional `options` declare a standard Nix option `type`, default, and description. `lib.evalModules` performs option validation and merging; the catalog only describes domain metadata. `defaultPlatforms` narrows where a default-enabled feature is enabled without narrowing its supported platforms. `defaultFrom` enables a feature by default when any listed feature is enabled; an explicit setting still wins. The catalog rejects invalid defaults, overlapping option paths, unknown references, and dependency/default cycles.

Shared defaults are passed through upstream `lib.mkDefault`; host input is evaluated as a Nix module definition. No custom interpreter walks Nix module properties. The host loader supplies shared presets as `profile`; hosts select them through `features`. Attribute-valued options follow their declared upstream merge type; a stronger definition can replace an entire nested value. `lib.mkDefault`, `lib.mkForce`, `lib.mkIf`, `lib.mkMerge`, and list ordering use upstream module semantics. Ordinary host definitions override shared defaults, including explicit null image paths and empty lists. Lists at the same priority concatenate; conflicting scalar definitions produce standard Nix diagnostics. Configuring an option does not implicitly enable its feature. The resolved tree is passed to Home Manager as read-only `config.features`; hosts configure it in `default.nix`, while `home.nix` retains upstream module settings and package overrides.

`portScopes` declares which feature scopes require a platform implementation. Each `nix/ports/<platform>/default.nix` registers those implementations. The feature loader validates missing registrations and required service contracts before loading them. Dependency activation paths refer to the actual system or home options. Choice rules can restrict their `platforms`; desktop choice applies to Arch and native NixOS. The generic resolver does not branch on GNOME, Niri, DMS, wallpaper or launcher identities. Desktop settings use `desktop.gnome.settings` (dconf), `desktop.niri.settings` (KDL), `desktop.dms.settings/session` (JSON), `desktop.wallpaper.image/lockImage`, and `desktop.launcher.hiddenEntries`. Business defaults and rendering remain in their modules.

Arch desktop integrations require native packages with the appropriate units and ABI; provider selection still goes through the shared software layer. Noctalia reuses Home Manager's upstream configuration generator; its Arch session service uses the software layer's selected executable. The DMS adapter manages JSON and native service symlinks because the upstream HM module unconditionally installs its Nix runtime. Its system interface and Home Manager service request each contribute to one native user service; either can enable it independently. It runs only with the Niri system session, preserving the package's DBus notification service and restart behavior. Native GNOME extensions are enabled by UUID rather than copied into the Nix profile. The GNOME feature explicitly requests the selected Arch desktop packages, including GDM, rather than a pacman package group. Arch and NixOS share one desktop-stack selection. Enabled GUI features supply candidates; the catalog orders Niri before GNOME. An explicit `preferences.desktop` takes precedence and must name an available stack. Shared desktop policy binds GNOME to GDM and Niri to greetd, so their defaults follow the same selected stack; explicit upstream-style overrides still apply. Other enabled desktops remain available. DMS and Noctalia supply Niri when used without the Niri feature, while its existing compositor dependency checks still apply. There is no independent `preferences.loginManager`; NixOS service customization uses upstream options. The selected Niri shell supplies its matching greetd UI (DMS Greeter or Noctalia Greeter); bare Niri uses tuigreet. After package installation and file linking, native activation installs dedicated greetd configuration when selected, enables the chosen login manager using sudo, and sets graphical.target as the default boot target. The greetd drop-in reads `/etc/greetd/nixconfig.toml`, preserving the original host configuration. It installs the new display-manager alias before disabling the previous manager’s boot links, without stopping services or using --now. Repeated activation is a no-op when the boot configuration matches. On Arch, disabling the last managed login manager removes its owned next-boot enablement and configuration while leaving the running session intact. Missing ownership state never authorizes removal of an existing login manager. Changes made outside the managed state are preserved or reported as conflicts. GNOME requests its own portal and keyring packages even without Niri; the keyring feature independently controls the user units. Launcher rules inspect native entries at activation time; on Arch, both Nix and native sources use one activation-owned override per filename, so a provider change does not collide with HM link preflight. A checksum manifest permits cleanup without overwriting or deleting user-owned edits. NixOS instead uses declarative Home Manager links to the filtered build output; its launcher adapter does not scan native paths at activation.

Platform and software source are separate decisions. Platform adapters use explicit names such as `isArch` when a check is needed, and are selected through platform imports. Common features use the resolved software provider (for example `usesNixPackage = software.vim.provider == "nix"`) only when packaging changes configuration behavior. A host's preferred manager does not imply the provider of every application. Features without a packaging difference need no provider branch. Arch session, service, and filesystem assumptions remain in `nix/ports/arch/`; NixOS-specific Home Manager adapters live in `nix/ports/nixos/home/`. Adding another distribution does not opt it into Arch assumptions. Shared desktop/greeter defaults live in `nix/lib/features/desktop-defaults.nix`; platform adapters derive execution from final module options and provide upstream or native service integration. NixOS coordination lives in `nix/ports/nixos/integrations/`, split into login-manager, keyring, SSH-agent and dconf modules. These modules connect upstream options rather than implementing replacement services. The dconf bridge enables system support when Home Manager actually declares dconf settings or databases, including consumers outside desktop features.

Chrome extension files on Darwin belong to Home Manager's `programs.google-chrome`, with `package = null` for Homebrew. NixOS delegates `ExtensionSettings` to `programs.chromium.extraOpts`, preserving `normal_installed`; upstream applies this policy to Chrome, Chromium, and Brave without installing those browsers. Only Arch writes a dedicated root policy file through its ownership adapter.

## Layers

1. **Features** declare software identities and capability requirements, then configure applications using the resolved software.
2. **Definitions**: `profiles.nix` declares software groups and their Nix/Homebrew/pacman mappings; `profile-requirements.nix` projects those groups into software requirements. `catalog.nix` combines these with application recipes and rejects conflicting duplicate identities. `recipe-constructors.nix` provides recipe constructors.
3. **Resolution** (`resolve.nix`) merges explicit requests, checks platform support and capabilities, selects a provider, and matches extras to software identities. Its shared installation planner reconciles extras against confirmed installation owners.
4. **Providers** (`providers.nix`) define supported platforms, fallback order, recipe validation, package identity, command paths, and installation plan formats.
5. **Runtime planning** (`materialize.nix`) incorporates final packages produced by upstream modules, finalizes extra ownership, and supplies explicit command paths. Consumer declarations connect software identities to upstream options and report the final packages installed in each scope. NixOS/Home Manager build the Nix profiles and resolve output selection, priorities and file collisions.
6. **Port installation adapters** consume the plan through Home Manager, NixOS/nix-darwin, Homebrew declarations, or pacman/yay commands during Home Manager activation.

The host/system `software.plan` is authoritative. Home Manager contributes requirements, explicit overrides and final upstream wrappers, then consumes that same plan. System configuration can add requirements and overrides without reaching into the managed user's internals. The two scopes do not resolve providers independently. Base tools and optional features use the same resolution process; shared profile entries reuse the same recipe.

Features request every resource they configure, including fonts. For example, VSCode and Ghostty each request Maple Mono directly. Requests merge across features and keep their own installation scopes. The software catalog maps identities to providers; it does not implement a package dependency graph. Nix and native package managers remain responsible for package dependencies.

Both Nix and Homebrew adapters check that their final installation manifests contain every requested installation. Explicit additions remain valid; removing a requested package by overriding the assembled manifest fails evaluation.

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

The shorthand `packageManager = "homebrew";` is equivalent to `{ type = "homebrew"; extraPkg = { }; }`. Use the structured form for extras:

```nix
packageManager = {
  type = "homebrew";
  extraPkg = {
    homebrew = {
      brews = [ "aria2" "rsync" ];
      casks = [ "coteditor" ];
    };
    nix.packages = [ "hello" ];
  };
};
```

Arch distinguishes repository packages from AUR packages:

```nix
packageManager = {
  type = "pacman";
  extraPkg = {
    pacman = {
      packages = [ "rsync" ];
      aur = [ "google-chrome" ];
    };
    nix.packages = [ "hello" ];
  };
};
features = { devel.enable = true; ghostty.enable = true; };
```

The Nix backend accepts attribute paths, for example `extraPkg.nix.packages = [ "aria2" "llvmPackages.clang" ];`. These groups are explicit installations, independent of the default `type`; Nix is not merely a fallback here. Names need not be present in the identity catalog. Unknown fields, invalid names, and unsupported managers fail evaluation.

Extras that match active software identities follow those identities' selected providers, overrides, and wrappers. For example, the GPG agent integration requires Nix store packages, so an extra Brew `gnupg` request is satisfied by that integration instead of installing another copy through Brew. If no feature or base requirement requests that identity, the extra remains an independent installation request. Extras do not enable feature configuration.

The same rule prevents an extra `mpv` request from installing an unconfigured player alongside Home Manager's configured wrapper. An explicit Nix output, such as `llvmPackages.llvm.dev`, is also reconciled when an active recipe already provides it. Requesting the same pacman package from both a repository and AUR is rejected.

Darwin, Arch, PC, and Pad enable `features.commonTools.enable` for aria2, GnuPG, GnuTLS, Graphviz, ncurses, OpenSSL, pinentry, rsync, SQLite, xz, zlib and zstd. These requirements prefer the selected manager and fall back to Nix when needed. GnuPG and pinentry reuse existing identities: enabling GPG requires a Nix GnuPG package for the managed agent, while pinentry keeps its selected provider. Matching requests and extras are deduplicated. Disabling commonTools removes only its requests. Linux procps belongs to commonTools. WSL selects terminal pinentry through its package override. Host differences such as watch and generic pinentry on Darwin remain in `extraPkg`.

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

Select an existing provider in `systemConfig` (or contribute an identity override from `homeConfig`):

```nix
software.providerOverrides.vim = "nix";
```

This is a strict selection: unavailable recipes and unmet capabilities fail rather than silently falling back. It does not enable the feature. `packageManager.type` remains the default for other identities. A Nix package override conflicts with an explicit non-Nix provider for the same identity.

Replace a feature's Nix package through the same host software interface:

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

Nix commands are exposed through the upstream Home Manager and system profiles.
The software layer does not expand `meta.outputsToInstall`, sort raw package
`bin` directories, or create a second executable environment. `buildEnv` owns
output selection, propagated packages, file collisions and `meta.priority`.
Explicit upstream `home.packages` entries participate in that same environment. Use `software.packageOverrides` to replace feature-owned software; do not hide an alternative implementation in PATH or a second profile entry. Standard upstream package priorities remain authoritative for intentional additional packages.

`software.plan.binPaths` contains only native provider paths. When those paths
are added to the user environment, the Home Manager profile comes first,
followed by the system profile on NixOS/nix-darwin. On Darwin, system PATH places
native paths after Nix profiles and before OS defaults. Homebrew formula paths
and `bin`/`sbin` remain available, including linked cask commands such as `cot`.
Explicit feature commands use the resolved package or native command path.

Extras are deduplicated against confirmed installations: native selections,
centrally installed Nix packages, or active upstream runtime packages. Disabling
an upstream program does not absorb an explicit extra or install its inactive
wrapper. Independent Nix extras receive a lower `meta.priority` than selected
software, considering final wrappers; this policy is computed once by the
installation planner. Upstream profile assembly resolves the resulting files.
Equal-priority conflicts remain errors. Host PATH customizations must be explicit module configuration; they are not a supported way to replace a feature-owned command.

## pacman and AUR activation

A pacman recipe uses `type = "package"` for an official repository package or `type = "aur"` for an AUR package. Both belong to the same native backend. For example, `pacman = aur "google-chrome";` still produces a resolved identity with provider, package name, capabilities, and selection reason.

The Maple Mono AUR names are `maplemono-nf-cn` and `maplemono-ttf`, as documented upstream. They differ from ArchLinuxCN's `ttf-maplemono-*` names.

The host software backend schedules native installation after the write boundary and before Home Manager links the new configuration. Arch's system and home phases share the activation DAG, but privileged operations are declared by the system port:

1. Query the pacman database and select packages that are not installed. Existing packages are not automatically upgraded.
2. Validate prerequisites before the first installation, then run `/usr/bin/sudo /usr/bin/pacman -S --needed` for repository packages.
3. Run `/usr/bin/yay -S --needed --aur` as the Home Manager user, preserving normal interaction and rejecting root AUR builds.
4. Include `base-devel` and Git when AUR packages are requested. The user must install yay beforehand; activation fails clearly if it is required but missing.

Home Manager dry-run skips installation and does not require the target tools to exist. Installation failures stop activation and preserve the failing exit status. The backend does not run `-Sy`, perform a full system upgrade, remove unrequested packages, or clean AUR build dependencies. Maintain Arch through normal system upgrades; if stale repository metadata prevents installation, update the system before activating again.

Changing a provider does not implicitly uninstall a native package. For a deliberate migration, also declare `software.migration.removeReplaced = [ "htop" ];`. The backend only removes requested identities after a usable Nix replacement exists and native reverse-dependency, login-shell and system-unit checks succeed.

Arch system-scoped Nix tools use an upstream `buildEnv` and a root-owned Nix profile at `/nix/var/nix/profiles/nixconfig-system`. Nix manages generations and garbage-collection roots; the port does not implement its own package generation engine.

Native installations are not rolled back with Nix generations, and successful native installation steps are not undone if a later activation step fails.

References: [pacman manual](https://man.archlinux.org/man/pacman.8.en), [yay manual](https://github.com/Jguer/yay/blob/next/doc/yay.8), [Maple Mono installation guide](https://github.com/subframe7536/maple-font/tree/v7#arch-linux).

## Feature author interface

```nix
{ lib, software, ... }:
{
  software.requirements.git = { };
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
- `runtimePackage`: the actual Nix executable package, including an upstream wrapper when applicable; `null` for native software or a Nix identity without an active runtime or installation request.
- `command "executable"`: the executable's path in its runtime package or native provider's configured command directory. Requesting a command from an inactive module-owned Nix program fails explicitly.
- `providedCapabilities`: capabilities supplied by the selected recipe.
- `reason`: preferred provider, explicit override, or the reason for fallback.

Applications whose Home Manager modules accept `package = null` can use native installations directly. Modules requiring a Nix package path must declare that requirement:

```nix
software.requirements.zsh.capabilities = [ "store-package" ];
```

Zsh, GnuPG for the managed GPG agent, nh, and mpv script resources currently have this requirement. Pinentry follows the selected provider: upstream manages Nix pinentry packages directly; external pinentry uses `package = null` and a `pinentry-program` line pointing to the resolved command. GPG agent configuration and service ownership remain upstream. Git, Vim, Ghostty, commonTools and ordinary development tools can prefer native providers. On Arch, mpv itself uses pacman with `programs.mpv.package = null`; HM generates configuration, links the pinned scripts into the user scripts directory, and installs their font resources in the profile. The Nix wrapper remains active when mpv resolves to Nix, including NixOS and explicit package overrides. Homebrew mpv uses the same upstream configuration-only interface as pacman mpv. The shared Linux desktop preset enables mpv; Darwin defaults to IINA without mpv. Explicitly enabling mpv on Darwin prefers Homebrew.

Managed upstream package consumers are described in
[`package-options.nix`](../nix/modules/home/software/package-options.nix).
Each declaration is instantiated through
[`consumer.nix`](../nix/modules/software/consumer.nix), which generates the package
default, consistency assertion and runtime artifact together. Feature modules
retain application settings, without repeating the package assignment. Optional
third-party interfaces such as DMS register their consumer with the capability
module that supplies the interface. System consumers register in the relevant
port. The internal `software.consumers` inventory exposes these declarations for
auditing.

A consumer declares its software identity, `packageOption`, `enableOptions`,
optional `runtimePackageOption`, and `installedScopes`. An option path such as
`[ "programs" "mpv" "finalPackage" ]` refers to module configuration, not a file.
All `enableOptions` must be true; nested consumers such as Git LFS include both
the parent program and the subfeature switches. `installedScopes` lists only profiles where the upstream module actually installs
the final package; it is empty for service/resource references. Assertions check
these claims and explicit central requests against the resulting upstream package lists. Multiple consumers
can share an identity when they produce the same final package. Incompatible
final packages fail explicitly instead of selecting an arbitrary consumer.

`requestWhenEnabled` allows an independently enabled upstream consumer to request
its identity. Git LFS uses this so `programs.git.lfs.enable = true` follows the
selected provider even without the devel feature. Its enable conditions must not
depend on software resolution. On native providers, nullable package options use
`null` and the provider installs the software; Nix providers retain the upstream
package path. Explicit conflicting package assignments fail with a diagnostic
pointing to `software.packageOverrides`.

Requirements select identities and capabilities. `scopes` requests central
installation in `home` or `system`, defaulting to `[ "home" ]`. Use `scopes = [ ]`
when selecting a package as a resource or when an upstream consumer handles its
installation. Dependencies inherit requested scopes. Resource-only plugin lists
continue to use upstream list merging.

The planner subtracts confirmed upstream installation scopes from the requested
scopes. Additional scopes receive the same final upstream package. If an upstream
consumer is disabled, only that consumer's installation contribution disappears:
an independent system or home request still installs the selected package.
Without another installation request, a disabled wrapper is not replaced by an
unconfigured executable. Arch uses its system Nix profile for system requests.

Desktop integration is separate from package retention. For example, disabling
`programs.ghostty.enable` keeps the feature's explicit package request, but removes
its default terminal selection, `TERMINAL`, and Niri terminal shortcut. Disabling
`xdg.terminal-exec.enable` removes the automatic Niri Mod+Return binding for both
Nix and native providers. Explicit host shortcuts remain authoritative.
Desktop login commands belong to the host's [autostart declarations](features.md#desktop-autostart).
When a host startup command references the selected terminal, removing that role
also requires changing or disabling the host's startup entry.

For software that needs no additional configuration, declare a package-only feature in the catalog:

```nix
codex = {
  platforms = all;
  software = [ "codex" ];
};
```

Shared module requirements merge, with capability requirements combined. Ghostty directly requests Maple Mono; the Chinese feature can request the same font without a duplicate installation. The `font` capability enables Home Manager fontconfig for selected Nix fonts; native providers install native fonts themselves.

## Homebrew path metadata

`binDirs` lists subdirectories to add to PATH, relative to the formula's `opt/<name>` directory. Its default is `[ "bin" ]`, and list order is preserved.

`commandDir` selects the single subdirectory used by `command "executable"`. It defaults to `"bin"` and does not search `binDirs` or rename executables.

For example, coreutils uses `libexec/gnubin` for ordinary command names such as `ls`, while also adding its `bin` directory to PATH. Python adds both `libexec/bin` and `bin`: the former contains unversioned aliases such as `python`, while `command "python3"` points to `bin/python3`.

## Maintenance features

`features.efiTools.enable = true;` requests `efibootmgr`. It is disabled by default and supported on native NixOS and Arch. It does not change boot loader configuration or modify EFI variables automatically.

NixOS installs it into the system environment. Arch uses the selected backend: pacman installs the native package, while Nix installs it into the managed system profile. Base tools do not request it implicitly. NixOS-Pad enables it based on its existing EFI configuration; PC and Arch leave it disabled until selected by their hosts.

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

For Nix, removing the final request removes the package from the managed profile. Homebrew keeps `cleanup = "none"`: removing a manifest entry does not uninstall existing software or delete data. pacman/yay likewise installs missing packages without removing packages dropped from the manifest. Explicit Nix application overrides do not authorize native removal. Only identities also listed in `software.migration.removeReplaced` are eligible: after the Nix installer succeeds, the adapter removes matching installed pacman/AUR packages using plain `pacman -R --noconfirm`. Current native requirements are excluded. Account login shells and native active/enabled system services are checked before removal. Reverse dependencies make the transaction fail; recursive/cascading removal and dependency bypass are never used. Mere feature removal and implicit capability fallback do not trigger removal.

## Desktop input and settings lifecycle

The Chinese feature supports native Linux desktops only. Its common module enables the standard `i18n.inputMethod` interface, selects Fcitx5, and supplies `i18n.inputMethod.fcitx5.settings` and the two Rime preset patches. Direct interface overrides are respected on both platforms. NixOS delegates both configuration generation and the whole `fcitx5` directory link to the official HM module. Arch alone renders individual files from those settings, using native Fcitx/Rime/GTK/Qt packages. Both ports leave empty profile and global settings, and undeclared addon settings, unmanaged. An explicitly named addon requests its configuration file even when its sections are empty, following the upstream INI option type. The Arch autostart adapter keeps its owned Hidden entry after feature removal, preventing the retained package from restarting Fcitx at the next login; never-managed configurations are untouched. When input remains enabled and `i18n.inputMethod.fcitx5.systemd.enable = false`, the adapter removes its owned Hidden entry to restore desktop autostart. Its ownership stamp remains so disabling input later can suppress the retained native package again. Modified or unmanaged entries are preserved. The local working setup is represented as one Rime entry and English mode by default, without copying learned dictionaries or monitor-specific settings. GNOME integration applies to both distributions. WSL hosts use CLI tools and terminal pinentry without Fcitx or graphical-session dependencies.

Keyring and compositor packages can be OS-bound resources. Arch system adapters
continue to require native packages where GNOME, PAM, units or ABI need them.
A standalone user keyring can select either provider independently of the default
package manager. The Arch system port supplies `software.packageDefaults` to
disable NixOS wrapper paths in the default Nix package. The shared catalog and
resolver contain no keyring-specific platform branch or recipe callback.
Defaults preserve provider selection; explicit `software.packageOverrides` win
and remain subject to the port's compatibility assertions. Matching extras retain
the catalog's original software identity for deduplication.
NixOS's upstream keyring module has no package option, so package customization
uses a system overlay; a mismatched home-only override is rejected. The Nix user
service comes from the official HM `services.gnome-keyring` module.

All Linux hosts retain the official Home Manager dconf activation and generation key manifests. The pinned upstream module resets removed keys while a database remains configured, but skips a database removed entirely. A separate `dconfRemovedDatabases` hook handles only that gap: it resets the previous generation's keys for databases with no manifest in the new generation. Cleanup runs before upstream writes, so moving between `dconf.settings` and `dconf.databases.user` cannot reset newly applied values in their shared database. If `DCONF_PROFILE` is nonempty, removed-default-database cleanup is skipped with a warning: the previous manifest does not record that runtime profile, so its database identity cannot be inferred safely. Named databases remain independently identifiable. It never overrides `dconfSettings`, scans the live database, or maintains its own state. With no previous generation or a garbage-collected manifest, cleanup is skipped; current declarations are still applied by Home Manager. Reset means schema defaults, not restoration of pre-management values. Manual edits to previously managed keys follow the same reset semantics as upstream.

Default login sessions are used by tuigreet explicitly. The DMS greeter seeds its session memory once per changed default while retaining the remembered username and later interactive session selections. GNOME defaults to GDM; Niri with DMS uses the DMS greeter, and bare Niri uses tuigreet.

## Native system services

`features.desktop.printing` and `features.desktop.firmware` are independent features on Arch and native NixOS, default-enabled by GNOME/Niri/DMS. The NixOS adapters use `services.printing`, Avahi, and `services.fwupd`; GNOME may retain its own Avahi requirement when printing is disabled. Arch requests native host packages and declares required units through the internal `native.systemd.units` backend. Multiple modules' lists merge and deduplicate. The desktop-session adapter also supplies NetworkManager/Bluetooth and native audio, power and file services. HM manages PipeWire/WirePlumber user units. A preflight rejects competing active network managers before mutations. The internal `native.systemd.enableOnly` option tracks boot-time units such as NetworkManager-wait-online without starting them during activation. Printing requests `cups.socket` and both Avahi units; smart cards request `pcscd.socket`; firmware requests only `fwupd-refresh.timer`, while the firmware daemon remains DBus-activated. The timer refreshes metadata, not device firmware. See [ArchWiki CUPS](https://wiki.archlinux.org/title/CUPS) and [fwupd](https://wiki.archlinux.org/title/Fwupd).

The adapter runs after package installation and file linking, including when the last service feature is removed or the package manager changes. Its root-owned state separates each account's requested units and initial service states from the symlinks created by enable operations. To compute the combined enablement requirements, the installed `systemctl` runs offline against a disposable copy of `/etc/systemd/system` in a private mount namespace. Vendor `Also=`, `Alias=`, templates and drop-ins remain systemd's responsibility. Planning requires root mount-namespace support and fails before live changes if unavailable. It does not contact or reload the host manager.

Only planned links that were absent before enable are journaled as owned effects, including implicit peers. The adapter records initial peer states before mutation, but only explicitly requested units are eligible for runtime cleanup. Multiple accounts share the union of enablement requirements. Cleanup removes only unchanged owned links no longer in that union and reloads systemd. Enable, reload and stop operations retain retry state, with an exclusive adapter lock and atomic writes. Do not run external service configuration changes concurrently with activation; the lock serializes this adapter, not administrators or package hooks.

Before stopping an originally inactive/disabled unit without remaining external boot links, the adapter queries systemd's live reverse dependencies and stop-propagation relations. Protection includes aliases, cycles and inactive intermediate units; active foreign consumers preserve their dependencies. Existing enabled/active units, edited links and native packages remain intact. Implicit enablement alone does not authorize stopping a service. The adapter never masks a unit or turns off DBus activation. State migration retains recorded ownership evidence; links without evidence remain host-owned.

Display managers use a separate adapter because changing them must not terminate a graphical session. GDM/greetd switching updates boot configuration without `--now`, and retries check both services even after the alias has already changed. Disabling the final managed login manager retires its owned boot links and greetd files without stopping the running GUI. Without an ownership record, existing login configuration is left unchanged.

Platform-specific activation helpers live in `nix/assets/helpers/<platform>/`; shared utilities live in `nix/assets/helpers/common/`. Feature modules declare capabilities and requirements; platform adapters translate them into native requests. Portable lifecycle tests cover ownership transitions, shared implicit peers, interrupted operations, external edits and stop protection. A Linux VM check also runs the production helper against real systemd to verify isolated enable planning, vendor aliases and stop propagation.

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

Tests cover provider preference, missing/unavailable/incapable-provider fallback, shared resource requests, feature removal, scopes, invalid catalogs and managers, Homebrew integration, and Home Manager adapters.

Software consistency regressions cover package overrides, required outputs, output priorities, inactive consumers, cross-scope ownership, optional upstream consumers, and system/user Zsh ownership. Runtime tests use small executable packages with real Home Manager modules and Nix profiles to verify mpv wrapping, stale native commands, compiler priority overrides, and extras alongside final wrappers. Linux's devel test builds C/C++ examples using real toolchains.

pacman/yay activation tests use substitute commands to verify installation order, already-installed packages, dry-run, prerequisite checks, and failure propagation. They do not invoke real sudo or install native packages.


## Platform and mutation boundaries

[`lib/platforms/default.nix`](../nix/lib/platforms/default.nix) is the shared deployment
platform registry for host construction, feature validation and software
providers. `arch` is distribution-specific; Nix systems such as `x86_64-linux`
remain CPU/OS targets. Shared experience presets are plain attribute sets in `nix/lib/hosts/profiles.nix`,
while `hosts/` contains only actual machines. See [Creating hosts](hosts.md).

NixOS and Darwin use their upstream system/Home Manager modules. Arch's system
service, policy, input-autostart and native-package adapters are loaded through
its platform entry point. Package command rendering remains in helpers; activation ordering and profile
paths belong to the consuming port. Arch-specific service requirements are not copied
into NixOS or Darwin activations. NixOS uses official HM dconf, Fcitx5 and
Keyring modules. Arch also uses upstream dconf; the shared removed-database hook supplements its generation-based cleanup.

Native recipes list applications and capabilities explicitly requested by this
configuration. Pacman/yay resolve their current dependency graph, providers,
versions and conflicts at transaction time. Removal uses plain `pacman -R`,
without recursive removal or dependency bypass. This repository does not pin or
reimplement Arch's dependency graph. Unit activation uses the installed systemd
unit definitions; dependencies and `Also=` peers outside the explicitly managed
unit set are not claimed for automatic cleanup. Before stopping a retired unit, the adapter checks the current reverse dependency graph and preserves units with active consumers outside the retiring set. Queries use checked `systemctl show` calls: command failures or unknown active states abort reconciliation instead of being recorded as inactivity. Cleanup failures retain ownership records for retry.

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
`nix/assets/helpers/common/`. They open parent directories without following symlinks,
use temporary files in the destination directory, and recheck managed content
before deletion. Application data, personal dictionaries and unrelated files
are outside these tools' cleanup scope. Activations are retryable rather than
an atomic transaction across the whole Arch system; a failure can leave earlier
successful changes applied. Inspect the reported conflict and retry instead of
removing entire configuration directories.


## Ownership and regression requirements

Before adding an activation helper, inspect the pinned NixOS, nix-darwin and HM
modules. Use their public options when available. Shared features express intent;
native adapters supply only the missing interface. Do not replace an upstream
activation node to hide a migration or file conflict. A declared file
must have one owner and stable ownership granularity (whole directory versus
individual children). Conflicts stay visible; automatic backup, `force`, deleting
user paths and suppressing errors are not repairs for overlapping ownership.

Vim uses official `programs.vim` for the Nix wrapper and pinned plugins. Native
Vim has no HM `package = null` interface, so its configuration is generated with
`pkgs.vimUtils.vimrcFile` using the same plugins. Plugin sources come from the
locked nixpkgs plus two fixed-revision, fixed-hash sources in the Vim feature.
Universal Ctags is a Vim feature dependency selected through the software provider layer. Both Vim configurations point Tagbar at the resolved executable, avoiding an incompatible system ctags earlier in PATH. Plugin sources are not downloaded or updated during activation or startup. User plugin data is preserved. `nix/modules/software/nixpkgs.nix` supplies one narrow default
unfree-package policy to the system builders and standalone HM: Chrome, VS Code,
a.vim and DoxygenToolkit.vim. Hosts can replace this predicate. Package license
checks remain enabled, with only the listed unfree packages allowed by default. Formatter failures are tested against unsaved buffers and real
files in an isolated temporary home. The runtime test also verifies that Tagbar resolves a real C++ symbol for both generated Vim configurations.

Changes to ownership or native mutation need lifecycle evidence: initial apply,
repeat apply, change, disable, re-enable, interrupted operation, foreign files,
and provider transitions where supported. Include a negative case proving an
unmanaged or modified file survives; run the real upstream preflight when the
failure belongs to HM. Native removal must fail if systemd cannot be queried,
and must protect active/enabled units of all relevant system unit types.

Keep verification levels distinct: evaluation checks options and assertions;
profile builds detect package collisions; isolated activation tests verify file
and helper behavior; native login, hardware and other operating systems require
separate runtime validation. None of these is a proof against every future
upstream change. Keep failing checks visible and identify known upstream blockers
instead of weakening the checks or calling evaluation a successful deployment.


## Writable VS Code settings

`features.vscode.settings` declares values restored on every Home Manager
activation. The feature uses
upstream `programs.vscode.profiles.default.mutableUserSettings = true`, with
the selected package or `null` for Homebrew/pacman. There is no custom JSON
writer or initialization marker.

The settings file remains writable. Declared values win during activation;
undeclared values, including nested object keys, survive. Objects merge
recursively; declared arrays replace the corresponding array. Removing a
setting from the declaration stops enforcing it and retains its current value.
The upstream operation accepts JSONC/JSON5 input but rewrites formatted JSON,
so comments and original formatting are not preserved. Invalid input aborts
activation without overwriting the file.
