# NixConfig

English · [简体中文](README.zh.md)

Declarative system and user configurations for NixOS, WSL, macOS, and Linux. Hosts share a common configuration with independent feature selection and local overrides.

- NixOS desktops: GNOME or Niri with DankMaterialShell.
- Application profiles: Git, Zsh, GPG, Ghostty, and mpv.
- Development tools (`devel`): Clang/LLVM, LLDB, CMake, Ninja, Meson, Autotools, binary inspection tools, and Python 3.
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
};
```

Feature defaults and platform support are defined in the [feature catalog](nix/lib/features/catalog.nix). Declare only changes to the defaults. Disabling a feature removes this repository's customization without blocking other modules or deleting application data.

Features provide their own required tools and may share packages. For example, `devel` includes Git; `git` adds the user identity and aliases.

Native NixOS enables `network` by default: systemd-networkd with systemd-resolved. Desktop features share this capability and default to NetworkManager with systemd-resolved. Set `networking.networkmanager.enable` in `system.nix` to select NetworkManager (`true`) or networkd (`false`) independently of the desktop. WSL, macOS, and standalone Home Manager retain their platform's network management.

To add a host, copy the matching directory from [nix/templates/](nix/templates/) into `hosts/<name>/`, complete its configuration and state versions, then register it in `hosts/default.nix`. Native NixOS also requires a hardware configuration and boot loader.

## Layout

```text
flake.nix      Dependencies and shared user settings
hosts/         Machine configurations
nix/
  modules/     System, user, and feature modules
  packages/    Shared package selections
  templates/   Host templates by platform
  lib/         Configuration assembly
  tests/       Configuration checks
```

## Validation

```sh
nix flake check --all-systems
```

## License

[Apache License 2.0](LICENSE) · Copyright © 2026 HsingYun
