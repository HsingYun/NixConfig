# Creating hosts

Hosts contain machine-specific choices. Shared experience presets live in
[`nix/lib/hosts/profiles.nix`](../nix/lib/hosts/profiles.nix); deployment platforms
are defined in [`nix/lib/hosts/platforms.nix`](../nix/lib/hosts/platforms.nix).
Feature definitions and package recipes remain in their respective libraries.
Do not copy platform adapters into a host.

## Platform versus CPU architecture

`platform` selects the deployment model. `system` is the Nix CPU/OS target.
They are deliberately separate.

| `platform` | Typical `system` | Output | Default package manager |
| --- | --- | --- | --- |
| `arch` | `x86_64-linux` | `homeConfigurations` | `pacman` |
| `nixos` | `x86_64-linux`, `aarch64-linux` | `nixosConfigurations` | `nix` |
| `nixos-wsl` | `x86_64-linux` | `nixosConfigurations` | `nix` |
| `darwin` | `aarch64-darwin`, `x86_64-darwin` | `darwinConfigurations` | `homebrew` |

`arch` means Arch Linux, including Arch under WSL; it is not a generic Linux
adapter. The former `platform = "linux"` spelling is no longer accepted.
Do not change `x86_64-linux` to `x86_64-arch`. A valid `system` does not guarantee
that every selected application has a package for that CPU architecture.
The checked-in machine configurations target x86_64 Linux and Apple Silicon.
Build the actual target configuration when adding another architecture.

NixOS uses NixOS service modules and a declarative system generation. Darwin uses
nix-darwin and Home Manager, with native applications integrated through the
official Homebrew module. Arch uses Home Manager for user configuration and a
separate adapter for native packages, owned policy files and systemd services.
These Arch activation hooks are not loaded by NixOS or Darwin hosts.

## Common steps

1. Create `hosts/<name>/default.nix` and `home.nix` using the examples below.
2. Register the directory in `hosts/default.nix`, for example:
   ```nix
   MyHost = ./MyHost;
   ```
3. In `home.nix`, set `home.stateVersion` to the initial Home Manager version for
   this user environment. Preserve an existing value when migrating. Do not bump
   state versions simply because the flake inputs were updated.
4. Optionally override `user.username`, `user.git.name`, `user.git.email`,
   `hostname`, and `homeDirectory` in the host definition. Omitted user fields
   inherit the settings passed by `flake.nix`.

A minimal `home.nix` is:

```nix
{ ... }:
{
  home.stateVersion = "26.05"; # Example only: use this environment's initial version.
}
```

Use nested feature options such as `features.desktop.niri.enable = true`.
The presets are plain attribute sets: use `lib.recursiveUpdate` or explicitly
merge a nested group when changing one nested value. A shallow `//` replaces
that entire nested group.

## Arch desktop

`hosts/MyArch/default.nix`:

```nix
let
  profiles = import ../../nix/lib/hosts/profiles.nix;
in
{
  platform = "arch";
  system = "x86_64-linux";
  packageManager = "pacman";
  features = profiles.linuxDesktop // {
    desktop = profiles.linuxDesktop.desktop // {
      gnome.enable = false;
    };
  };
  preferences = {
    desktop = "niri";
    loginManager = "greetd";
  };
  homeConfig = ./home.nix;
}
```

This host selects Niri/DMS and explicitly disables GNOME from the shared preset.
To add GNOME, change the feature override to `gnome.enable = true`. To choose it
at boot, also set `desktop = "gnome"` and `loginManager = "gdm"` in preferences.
Preferences do not enable or disable features. One login manager owns the
boot alias; applying a change does not stop the current desktop session.

Install Nix and Home Manager prerequisites on Arch first. The native adapter
requires pacman, sudo, a running systemd system instance, and yay when AUR
packages are selected. It does not bootstrap yay or perform an unattended full
OS upgrade. Keep Arch updated as a complete system; do not refresh package
indexes in isolation to create a partial upgrade.

Only explicitly required application/capability packages belong in the feature
catalog. Pacman/yay resolve their current dependency graph, including version
constraints and providers. Never copy `pacman -Qi` dependency lists into Nix.
Turning a feature off retains native packages. An explicit
`software.packageOverrides.<identity> = pkgs.<package>` selects Nix and removes
the corresponding native application with ordinary `pacman -R` after the Nix
package is installed. Native reverse dependencies, login shells and active or
enabled system units can block that migration. Host desktop components such as
Niri, portals and Keyring must retain their native provider on Arch.

Build first, then apply when ready:

```sh
nix build .#homeConfigurations.MyArch.activationPackage
home-manager switch --flake .#MyArch
```

Existing unmanaged files are conflicts, even if they contain the same text.
Inspect and explicitly relocate them before allowing this configuration to own
their paths. Do not delete whole configuration directories to resolve a conflict.

## Native NixOS: PC or tablet

Use the Arch example with these changes:

```nix
{
  platform = "nixos";
  system = "x86_64-linux";
  packageManager = "nix";
  hardwareConfig = ./hardware.nix;
  systemConfig = ./system.nix;
  homeConfig = ./home.nix;
  # Also set features and preferences as in the desktop example.
}
```

Generate `hardware.nix` for the real machine using `nixos-generate-config`.
Configure its boot loader, filesystems and initial `system.stateVersion` in the
system configuration. **The checked-in NixOS-PC hardware file is an evaluation
placeholder and must not be used to install a real machine.**

For a GNOME tablet, use this feature selection instead of the full desktop preset:

```nix
features = profiles.linuxDesktop // {
  desktop = profiles.linuxDesktop.desktop // {
    niri.enable = false;
    dms.enable = false;
    gnome = {
      enable = true;
      settings."org/gnome/desktop/a11y/applications".screen-keyboard-enabled = true;
    };
    screenRotate.enable = true;
  };
};
preferences = { desktop = "gnome"; loginManager = "gdm"; };
```

Sensor orientation and touchscreen calibration are hardware-specific; inspect
the existing Pad host for examples without copying its device-specific values.
For an ARM machine select `system = "aarch64-linux"`, supply its real hardware
and boot configuration, and check package availability for the selected features.

```sh
nix build .#nixosConfigurations.MyPC.config.system.build.toplevel
sudo nixos-rebuild switch --flake .#MyPC
```

## NixOS-WSL

```nix
let profiles = import ../../nix/lib/hosts/profiles.nix;
in {
  platform = "nixos-wsl";
  system = "x86_64-linux";
  features = profiles.cli // {
    smartcard = { enable = true; allowBackgroundAccess = true; };
  };
  systemConfig = ./system.nix;
  homeConfig = ./home.nix;
}
```

Set the initial NixOS `system.stateVersion` in `system.nix`; do not provide a
native hardware/boot-loader module. The platform imports NixOS-WSL. Use
`{ pkgs, ... }: { software.packageOverrides.pinentry = pkgs.pinentry-curses; }`
in `home.nix`, alongside its state version, for terminal-only PIN entry.
No desktop or Chinese input method is selected. Smart-card device forwarding
into WSL must be configured outside this repository.

## Arch under WSL

Use `platform = "arch"`, `packageManager = "pacman"`, and `profiles.cli`, with
only `homeConfig`. Enable `smartcard.allowBackgroundAccess` if PC/SC must work
without an active local desktop session, and use `pinentry-curses` as above.
Systemd must be enabled in the WSL distribution for native service integration.
Do not select `profiles.linuxDesktop` or the Chinese feature for this setup.

## macOS / nix-darwin

```nix
let profiles = import ../../nix/lib/hosts/profiles.nix;
in {
  platform = "darwin";
  system = "aarch64-darwin"; # x86_64-darwin for an Intel Mac.
  packageManager = "homebrew";
  features = profiles.graphical // {
    coteditor.enable = true;
    iina.enable = true;
  };
  systemConfig = ./system.nix;
  homeConfig = ./home.nix;
}
```

Set nix-darwin's initial integer `system.stateVersion` in `system.nix`; it is
not a NixOS release string. Install Homebrew separately if using that backend.
Homebrew cleanup is disabled: removing a feature does not uninstall unrelated
native software. macOS retains its own desktop and input method facilities.

```sh
nix build .#darwinConfigurations.MyMac.system
darwin-rebuild switch --flake .#MyMac
```

## Validation

```sh
nix flake check --no-build --all-systems
```

This evaluates configured hosts and assertions, but does not build every host
closure or validate real hardware. Build the target output as shown above.
Tracked flake sources must include newly created files; for local work with
untracked files, use `path:.` in place of `.` in the flake reference.

References: [Arch package management](https://wiki.archlinux.org/title/Pacman),
[pacman removal and dependency checks](https://man.archlinux.org/man/pacman.8).
