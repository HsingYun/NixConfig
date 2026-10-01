# Mihomo

The `mihomo` feature runs the Clash Meta core as a system service on Arch Linux,
NixOS and Darwin. It is independent of the desktop and starts at system boot.
The feature is not available on the WSL port.

```nix
features.mihomo = {
  enable = true;
  configFile = "/etc/mihomo/config.yaml";
  tunMode = true; # Default: request permission to use TUN.
};
```

`NixOS-Pad` enables this feature and uses `/etc/mihomo/config.yaml`.
Other existing hosts keep it disabled.

## Private configuration

Supply a complete Mihomo YAML file at the declared path before activating the
service. The file should be owned by root and readable only by root (`0600`).
The project neither creates nor overwrites this file, and never reads it during
Nix evaluation or copies it into the Nix store. Use a quoted absolute path, not
a Nix path literal such as `./config.yaml`. This feature rejects store paths.
When the feature is disabled, direct upstream NixOS service configuration retains
its normal `configFile` semantics, including store files containing public data.

This follows the upstream NixOS `services.mihomo.configFile` model. There is no
subscription downloader, settings merger or generated proxy configuration in
the feature. Mihomo's own YAML capabilities, including proxy providers and their
updates, remain available.

**`tunMode` grants permissions; it does not change the YAML.** Enable TUN in the
private file as well. For example, include these fields in your complete config:

```yaml
tun:
  enable: true
  stack: mixed
  auto-route: true
  auto-detect-interface: true
  dns-hijack:
    - any:53
    - tcp://any:53

dns:
  enable: true
  listen: 127.0.0.1:1053
  nameserver:
    - https://dns.alidns.com/dns-query
```

This is a TUN/DNS fragment, not a complete proxy configuration: keep your nodes,
proxy groups and routing rules in the same private file. On macOS, an explicitly
configured TUN device must use a `utun` name. Linux-only settings such as
`auto-redirect` should not be copied into a macOS config.

See the [upstream module explanation](https://wiki.nixos.org/wiki/Mihomo) and
[Mihomo TUN documentation](https://wiki.metacubex.one/config/inbound/tun/).

## Platform implementation

| Platform | Package and service |
| --- | --- |
| NixOS | Nix package; official `services.mihomo`, including its systemd credentials, dynamic user and TUN permissions |
| Arch Linux | Existing pacman/yay provider, with the `mihomo` AUR recipe; the Nix provider is also supported. The shared native backend owns `mihomo.service`, with systemd credentials and a dynamic user |
| Darwin | Homebrew by default, or Nix through the normal package resolver; nix-darwin manages a privileged launchd daemon |

The Arch recipe does not add a third-party repository. If `mihomo` is already
installed from a configured repository such as archlinuxcn, the package backend
keeps that installation. A host can select the Nix package explicitly using
`systemConfig.software.providerOverrides.mihomo = "nix"`.

Darwin uses a root LaunchDaemon so TUN is available before login; Linux capability
restriction through `tunMode` does not have a macOS equivalent. On every platform,
the actual network behavior is determined by the private YAML.

The portable system interface is `services.mihomo.{enable,package,configFile,tunMode}`.
NixOS retains the additional upstream options. Package changes go through
`software.providerOverrides` or `software.packageOverrides`, as for other services.

## Operations

On NixOS and Arch Linux:

```console
sudo systemctl status mihomo.service
sudo journalctl -u mihomo.service -b
sudo systemctl restart mihomo.service
```

On Darwin, with the default nix-darwin label prefix:

```console
sudo launchctl print system/org.nixos.mihomo
sudo launchctl kickstart -k system/org.nixos.mihomo
```

Darwin writes the daemon's output to `/private/var/log/mihomo.log`.
After editing the private YAML in place, restart the service. An unchanged path
does not trigger a Nix rebuild or a file-content watcher. Missing or invalid
configuration is a visible service failure; no placeholder, backup, or fallback
configuration is installed.

Disabling the feature retires the service through the platform's service manager.
Private YAML, downloaded provider data and native packages are preserved. On Arch,
unmanaged unit files, edited managed files and active external consumers are
protected by the native backend and may require an explicit conflict resolution.

These adapters configure this machine's core. They do not configure a browser's
proxy switch or another machine's network settings.
