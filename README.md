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

`platform = "arch"` selects Arch integration; `system = "x86_64-linux"` still selects the Nix CPU/OS target. Platform definitions live in [nix/lib/platforms/default.nix](nix/lib/platforms/default.nix).

Shared experience is defined in [nix/lib/hosts/profiles.nix](nix/lib/hosts/profiles.nix):

| Host | Default experience |
| --- | --- |
| ArchLinux | Niri + DMS + greetd; GNOME is opt-in, pacman/AUR preferred |
| NixOS-PC | Niri + DMS + greetd; GNOME is opt-in; hardware remains a placeholder |
| NixOS-Pad | GNOME + GDM, screen rotation, on-screen keyboard and touchscreen orientation |
| Darwin | Shared CLI/development/GPG tools, Ghostty, Chrome, VS Code and IINA; native macOS desktop |
| NixOS-WSL | Shared CLI/development/GPG/smart-card tools, terminal pinentry; no desktop or Chinese IME |

The `linuxDesktop` preset enables Niri + DMS, with greetd. Multiple GUI features can coexist: Niri/greetd takes priority over GNOME/GDM, and `preferences.desktop = "gnome";` selects the GNOME/GDM pair instead. Preferences do not enable or disable features. To replace a desktop entirely, disable its feature and dependents: PC/Arch can disable Niri/DMS and enable GNOME; Pad can disable GNOME/screen rotation and enable Niri/DMS.

Noctalia is disabled on all default hosts. For an enabled Niri feature, `features.desktop.niri.shell = "noctalia";` automatically enables Noctalia; `"dms"` does the same for DMS. Both packages and configurations can coexist, but only the selected shell autostarts. When Niri is the preferred desktop, its greeter follows the selected shell. With `shell = null`, selection uses already enabled shells, preferring DMS. See [Noctalia configuration](docs/features.md#noctalia).

## Usage

Requires Nix with flakes enabled and the configuration tool for the target platform.

### Manage with nixman

`nixman` is installed by the shared user software profile on every host. It
wraps NixOS/WSL, nix-darwin and standalone Home Manager with update previews,
generation management and confirmed cleanup. For the initial update, run it
directly from GitHub without cloning the repository:

```sh
nix run github:HsingYun/NixConfig/master#nixman -- --help
nix run github:HsingYun/NixConfig/master#nixman -- update \
  'github:HsingYun/NixConfig/master#Darwin'

# After applying this configuration
nixman status
nixman generation list
nixman update
```

Replace `Darwin` with the target host. The first update takes an explicit source;
later updates can reuse the source recorded in the running generation. Updates
build and preview a fixed candidate before confirmation. Activation defaults to
yes `[Y/n]`; cleanup defaults to no `[y/N]`. Run as your normal user; system
activation requests `sudo` when needed.

Use `generation info`, `generation diff` and `generation switch` to inspect and
select generations, or `rollback` to return to the previous one. `generation gc
--oldest N` removes the oldest N eligible generations; `--keep N` and
`--older-than 30d` provide retention policies. Without a policy, all unprotected
historical generations are eligible. `gc` collects unreachable store objects.
Both support `--dry-run`. Status, generation inspection and cleanup previews
support `--json`; the package includes Bash, Zsh and Fish completions. See the
[nixman guide](docs/nixman.md) for all commands, preview boundaries and the saved
`nixman.json` record.

### Apply with upstream tools

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

`features` is hierarchical: each feature has an `.enable` switch with its settings alongside it. Desktop features are grouped under `features.desktop`, including `gnome`, `niri`, `dms`, `noctalia`, `keyring`, `launcher`, `wallpaper`, `printing`, `firmware`, and `screenRotate`; GPG SSH support is under `features.gpg.sshSupport`. Groups have no master switch. Shared defaults and host overrides merge by field; explicit `false` and empty lists replace inherited values.

For example, enable Chrome with no default extensions:

```nix
features.chrome = {
  enable = true;
  extensions = [ ];
};
```

Keep these settings in `hosts/<name>/default.nix`; the resolved tree is shared with Home Manager and system modules.

Software installation is coordinated by one software layer. Hosts select `packageManager` and `features`; host-specific extras belong in `packageManager.extraPkg` using that manager’s native package names:

```nix
packageManager = {
  type = "homebrew";
  extraPkg.homebrew.brews = [ "watch" ];
};
features = {
  ghostty.enable = true;
  vim.enable = true;
  chrome.enable = true;
};
```

NixOS/WSL default to Nix. Darwin prefers Homebrew, falling back to Nix when an implementation is unavailable or cannot meet a feature's capabilities. Arch defaults to `pacman`, including AUR packages installed through yay. Unimplemented managers such as `apt` are rejected explicitly. Resolution uses the software catalog, not the machine's current installation state.

Features declare both configuration and software requirements. Shared dependencies are merged: Ghostty requests Maple Mono, which can remain installed for the Chinese feature after Ghostty is disabled. Niri launches a terminal through `xdg-terminal-exec` without choosing Ghostty implicitly.

Detailed feature settings and examples live in [Configuring features](docs/features.md).
Package ownership, overrides, writable settings and cleanup behavior are documented
in [Software architecture](docs/software.md). Platform implementation and extension points live in [Port contracts](docs/ports.md). Deployment prerequisites, including
Arch keyring PAM setup, live in [Creating hosts](docs/hosts.md). These English
references hold the detailed behavior contracts; the READMEs are entry points.

## Layout

```text
flake.nix      Dependencies and shared user settings
hosts/         Machine configurations
nix/
  apps/        Flake applications, including nixman
  contracts/   Stable public platform interfaces
  ports/       Platform implementations and registration
  assets/helpers/  Platform helpers and shared common utilities
  modules/     Shared system, user, feature and software modules
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
