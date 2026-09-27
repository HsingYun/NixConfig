# NixConfig

[English](README.md) · 简体中文

面向 NixOS、WSL、macOS 和 Linux 的声明式系统与用户配置。各机器共享基础配置，独立选择功能并设置差异配置。

- NixOS 桌面：GNOME 或 Niri + DankMaterialShell。
- 应用配置：Git、Zsh、GPG、Ghostty 和 mpv。
- 开发工具（`devel`）：Clang/LLVM、LLDB、CMake、Ninja、Meson、Autotools、二进制检查工具和 Python 3。
- 中文环境：简体中文 locale、CJK 字体、Maple Mono、Fcitx5 + Rime 雾凇拼音。

## 支持平台

| 平台 | 管理范围 |
| --- | --- |
| `nixos` | NixOS 与 Home Manager |
| `nixos-wsl` | NixOS-WSL 与 Home Manager |
| `darwin` | 通过 nix-darwin 与 Home Manager 管理 macOS |
| `linux` | 通过 Home Manager 管理用户环境 |

## 使用

需要已启用 flakes 的 Nix，以及对应平台的配置工具。

```sh
git clone https://github.com/HsingYun/NixConfig.git
cd NixConfig
```

在 [flake.nix](flake.nix) 中设置共享用户信息，并检查 [hosts/](hosts/) 下的目标配置。原生 NixOS 应先完成目标机器的硬件与引导配置。

在目标机器上执行对应命令：

| 目标 | 命令 |
| --- | --- |
| NixOS / NixOS-WSL | `sudo nixos-rebuild switch --flake .#HOST` |
| macOS | `sudo darwin-rebuild switch --flake .#HOST` |
| Linux 用户环境 | `home-manager switch --flake .#HOST` |

将 `HOST` 替换为 [hosts/default.nix](hosts/default.nix) 中注册的机器名。

## 定制

在 `hosts/<机器名>/default.nix` 中选择平台与功能。系统设置位于 `system.nix`，用户设置与软件包位于 `home.nix`。

例如，启用 Niri 桌面与中文输入：

```nix
features = {
  niri = true;
  dms = true;
  chinese = true;
};
```

功能默认值与平台支持见[功能目录](nix/lib/features/catalog.nix)，仅需声明与默认值不同的开关。关闭功能会撤去本仓库的对应定制，不阻止其他模块提供同一能力，也不删除应用数据。

各功能独立提供所需工具，允许共享软件包。例如，`devel` 提供 Git 命令，`git` 配置用户身份与别名。

原生 NixOS 默认启用 `network`，使用 systemd-networkd 与 systemd-resolved；桌面功能共享该能力，默认使用 NetworkManager 与 systemd-resolved。在 `system.nix` 中设置 `networking.networkmanager.enable`，可独立选择 NetworkManager（`true`）或 networkd（`false`）。WSL、macOS 和独立 Home Manager 保留所属平台的网络管理方式。

新增机器时，将 [nix/templates/](nix/templates/) 中对应平台的目录复制到 `hosts/<机器名>/`，补齐配置与 stateVersion，再注册到 `hosts/default.nix`。原生 NixOS 还需配置硬件与引导程序。

## 目录结构

```text
flake.nix      依赖与共享用户信息
hosts/         机器配置
nix/
  modules/     系统、用户与功能模块
  packages/    共享软件包列表
  templates/   各平台机器模板
  lib/         配置组装
  tests/       配置检查
```

## 验证

```sh
nix flake check --all-systems
```

## 许可证

[Apache License 2.0](LICENSE) · Copyright © 2026 HsingYun
