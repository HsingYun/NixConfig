# NixConfig

English · [简体中文](README.zh.md)

Declarative system and user configurations for NixOS, WSL, macOS, and Linux. Hosts share a common configuration with independent feature selection and local overrides.

- NixOS desktops: GNOME or Niri with DankMaterialShell.
- Application profiles: Git, Zsh, GPG, Ghostty, and mpv.
- Development tools (`devel`): Clang/LLVM, GCC, GDB/LLDB, build tools, Python, Go, Node.js/TypeScript, OpenJDK, Rust/Cargo, plus Git LFS, Protobuf, Abseil, coreutils, and Telnet.
- Chinese environment: Simplified Chinese locale, CJK fonts, Maple Mono, and Fcitx5 with Rime Ice.

## Platforms

| Platform | Managed scope |
| --- | --- |
| `nixos` | NixOS and Home Manager |
| `nixos-wsl` | NixOS-WSL and Home Manager |
| `darwin` | macOS through nix-darwin and Home Manager |
| `linux` | User environment through Home Manager |

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

## Configuration

Each host selects a platform and features in `hosts/<name>/default.nix`. System settings belong in `system.nix`; user settings and packages belong in `home.nix`.

For example, enable a Niri desktop with Chinese input:

```nix
features = {
  niri = true;
  dms = true;
  chinese = true;
  ghostty = true;
};
```

Feature defaults and platform support are defined in the [feature catalog](nix/lib/features/catalog.nix). Declare only changes to the defaults. Disabling a feature removes this repository's customization without blocking other modules or deleting application data.

Software installation is coordinated by one software layer. Hosts select `packageManager` and `features`; host-specific extras belong in `packageManager.externalPkg` using that manager’s native package names:

```nix
packageManager = {
  type = "homebrew";
  externalPkg.brews = [ "aria2" ];
};
features = {
  ghostty = true;
  vim = true;
  chrome = true;
};
```

NixOS/WSL default to Nix. Darwin prefers Homebrew, falling back to Nix when an implementation is unavailable or cannot meet a feature's capabilities. Standalone Linux requires an explicit package manager; Arch uses `pacman`, including AUR packages installed through yay. Unimplemented managers such as `apt` are rejected explicitly. Resolution uses the software catalog, not the machine's current installation state.

Features declare both configuration and software requirements. Shared dependencies are merged: Ghostty requests Maple Mono, which can remain installed for the Chinese feature after Ghostty is disabled. Niri launches a terminal through `xdg-terminal-exec` without choosing Ghostty implicitly.

Extras matching active software requirements follow that software's selected provider and wrapper. Selected Nix commands take precedence over stale native installations. Set `software.packageOverrides.<software-id>` in the Home Manager configuration to replace a feature's Nix package consistently across its installation plan and module configuration. Arch, PC and Pad also declare equivalent extra tools using their manager's package names, excluding macOS-only packages.

The default-enabled `vim` feature installs Vim through the selected provider and manages `~/.vimrc` from [nix/assets/vimrc](nix/assets/vimrc). Plugins remain managed by vim-plug. Back up an existing unmanaged `~/.vimrc` before activation. PC and Pad use Nix applications; Darwin prefers Homebrew, with provider-specific PATH handling generated centrally.

Disabling a feature removes its software requests while retaining shared requirements. Homebrew keeps `cleanup = "none"`, so removing a manifest entry does not uninstall existing software. Integrations requiring a Nix package path, including Zsh, GPG agent and mpv plugins, declare that capability explicitly. Resolution reports explain fallbacks.

Inspect a host's software sources:

```sh
nix eval --json .#lib.softwarePlans.Darwin
nix eval --json .#lib.softwareManifests.Darwin
```

See the [software architecture](docs/software.md) for catalog, capability and backend-extension contracts.

DMS uses the upstream Home Manager options `programs.dank-material-shell.settings` and `.session`. Nonempty values manage the corresponding JSON file declaratively (read-only); use `lib.mkForce { }` for either option to let DMS manage that file instead. Launcher exclusions are configured through `desktop.launcher.hiddenEntries`; only existing desktop entries are hidden.

Native NixOS enables `network` by default: systemd-networkd with systemd-resolved. Desktop features share this capability and default to NetworkManager with systemd-resolved. Set `networking.networkmanager.enable` in `system.nix` to select NetworkManager (`true`) or networkd (`false`) independently of the desktop. WSL, macOS, and standalone Home Manager retain their platform's network management.

To add a host, copy the matching directory from [nix/templates/](nix/templates/) into `hosts/<name>/`, complete its configuration and state versions, then register it in `hosts/default.nix`. Native NixOS also requires a hardware configuration and boot loader.

## Layout

```text
flake.nix      Dependencies and shared user settings
hosts/         Machine configurations
nix/
  modules/     System, user, and feature modules
  templates/   Host templates by platform
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

CI runs native checks on x86_64 Linux and Apple Silicon macOS. The `host-*` checks evaluate complete host outputs and their assertions without building or activating the entire machine. Feature tests exercise independent toggles individually and retain local combinations for dependencies, conflicts, and desktop choices.

Before deployment, build the actual output on its matching platform, for example:

```sh
nix build .#darwinConfigurations.Darwin.system --no-link
nix build .#homeConfigurations.ArchLinux.activationPackage --no-link
nix build .#nixosConfigurations.NixOS-Pad.config.system.build.toplevel --no-link
```

Cross-platform builds require a matching remote builder. These commands do not switch the current system.

## License

[Apache License 2.0](LICENSE) · Copyright © 2026 HsingYun
