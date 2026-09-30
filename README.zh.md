# NixConfig

[English](README.md) · 简体中文

面向 NixOS、WSL、macOS 和 Linux 的声明式系统与用户配置。各机器共享基础配置，独立选择功能并设置差异配置。

- NixOS / Arch 桌面：GNOME 或 Niri + DankMaterialShell；Arch 原生包由 pacman/AUR 提供，配置由 Home Manager 管理。
- 应用配置：Git、Zsh、GPG、Ghostty 和 mpv。
- 开发工具（`devel`）：Clang/LLVM、GCC、GDB/LLDB、构建工具、Python、Go、Node.js/TypeScript、OpenJDK、Rust/Cargo，以及 Git LFS、Protobuf、Abseil、coreutils 和 Telnet。
- 中文环境：简体中文 locale、CJK 字体、Maple Mono、Fcitx5 + Rime 雾凇拼音。

## 支持平台

| 平台 | 管理范围 |
| --- | --- |
| `nixos` | NixOS 与 Home Manager |
| `nixos-wsl` | NixOS-WSL 与 Home Manager |
| `darwin` | 通过 nix-darwin 与 Home Manager 管理 macOS |
| `arch` | 通过 Home Manager 与 Arch 原生适配器管理用户环境 |

`platform = "arch"` 选择 Arch 适配，`system = "x86_64-linux"` 仍表示 Nix 的 CPU/操作系统目标。平台定义统一位于 [nix/lib/platforms/default.nix](nix/lib/platforms/default.nix)，不再接受旧的 `platform = "linux"` 名称。

共享体验定义于 [nix/lib/hosts/profiles.nix](nix/lib/hosts/profiles.nix)，各主机只保留桌面选择和硬件差异：

| 主机 | 默认体验 |
| --- | --- |
| ArchLinux | Niri + DMS + greetd；GNOME 按需启用，包优先 pacman/AUR |
| NixOS-PC | Niri + DMS + greetd；GNOME 按需启用，hardware 仍为占位 |
| NixOS-Pad | GNOME + GDM，屏幕旋转、屏幕键盘和触屏方向调整 |
| Darwin | 共享命令行、开发工具、GPG、Ghostty、Chrome、VS Code 和 IINA；保留 macOS 桌面 |
| NixOS-WSL | 共享命令行、开发和 GPG/智能卡，使用终端 pinentry；不启用桌面和中文输入法 |

`linuxDesktop` 默认开启 Niri + DMS，配合 greetd。多套 GUI feature 可以共存，默认优先 Niri/greetd，其次 GNOME/GDM；设置 `preferences.desktop = "gnome";` 即可让 GNOME/GDM 整套成为默认，不会关闭其他已开启的桌面。如果要完全替换桌面，PC / Arch 可以关闭 Niri/DMS 后开启 GNOME；Pad 可以关闭 GNOME/屏幕旋转后开启 Niri/DMS。preferences 不负责启停 feature。

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

Home Manager 不自动备份冲突的非托管文件。文件冲突会停止激活并报错，需要明确处理后再重试。

`nixos-rebuild switch` 会立即激活，并报告失败的服务。`nixos-rebuild boot` 只准备下次启动，执行成功不代表 Home Manager 已激活。重启后如发现配置未生效，检查 `systemctl --failed` 和 `systemctl status home-manager-<用户名>`。

## 定制

在 `hosts/<机器名>/default.nix` 中选择平台与功能。系统设置位于 `system.nix`，用户设置与软件包位于 `home.nix`。

例如，启用 Niri 桌面与中文输入：

```nix
features = {
  desktop.niri.enable = true;
  desktop.dms.enable = true;
  chinese.enable = true;
  ghostty.enable = true;
};
```

功能默认值与平台支持见[功能目录](nix/lib/features/catalog.nix)，仅需声明与默认值不同的开关。关闭功能会撤去本仓库的对应定制，不阻止其他模块提供同一能力，也不删除应用数据。

`features` 使用层级结构，每个功能通过 `.enable` 控制，功能参数放在同一节点下。桌面功能位于 `features.desktop`，包括 `gnome`、`niri`、`dms`、`keyring`、`launcher`、`wallpaper`、`printing`、`firmware` 和 `screenRotate`；GPG SSH 支持位于 `features.gpg.sshSupport`。分组节点没有总开关。共享默认值与主机配置按字段合并，显式的 `false` 和空列表会覆盖共享值。旧的 `features.niri = true` 等写法已迁移为 `features.desktop.niri.enable = true`。

例如，启用 Chrome 并清空默认扩展列表：

```nix
features.chrome = {
  enable = true;
  extensions = [ ];
};
```

这些设置统一放在 `hosts/<机器名>/default.nix`，解析后供 Home Manager 和系统模块使用。

软件安装统一通过软件层处理。Host 选择 `packageManager` 和 `features`；主机独有的软件在 `packageManager.extraPkg` 中使用对应包管理器的原生包名声明：

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

NixOS/WSL 默认使用 Nix；Darwin 默认优先 Homebrew，缺少可用实现或不能满足功能能力时回退 Nix。Arch 默认使用 `pacman`，AUR 包由 yay 安装。`apt` 等尚未实现的后端会明确报错。选择依据来自软件目录，不依赖本机安装状态。

Feature 同时声明配置与软件需求，依赖自动合并去重。例如 Ghostty 需要 Maple Mono；关闭 Ghostty 后，中文功能仍可保留同一字体。Niri 通过 `xdg-terminal-exec` 启动终端，不再隐式选择 Ghostty。

功能参数和示例统一见英文文档 [Configuring features](docs/features.md)。
软件归属、包覆盖、可写设置和清理行为见 [Software architecture](docs/software.md)；
平台边界与扩展方式见 [Port contracts](docs/ports.md)。
部署前置条件（包括 Arch Keyring 的 PAM 配置）见 [Creating hosts](docs/hosts.md)。
README 保留使用入口，详细行为以这些文档为准，避免多处维护造成偏差。

## 目录结构

```text
flake.nix      依赖与共享用户信息
hosts/         机器配置
nix/
  contracts/   公开的系统与用户能力契约
  ports/       各平台实现与注册
  assets/helpers/  按平台分类的辅助实现与 common 共用代码
  modules/     系统、用户与功能模块
  lib/         配置组装与软件来源解析
  tests/       配置检查
```

## 验证

先检查所有平台的配置求值，包括已注册主机的完整系统或 Home Manager 激活输出：

```sh
nix flake check --no-build --all-systems
```

再在当前平台构建并执行检查：

```sh
nix flake check --print-build-logs
```

CI 在 x86_64 Linux 和 Apple Silicon macOS 上分别执行原生检查。`host-*` 检查会求值完整主机输出及其断言；`home-profile-*` 检查实际构建各主机的 Home Manager 软件目录以发现文件冲突，但不会激活配置或构建整台机器。`--no-build` 无法发现这类构建冲突。功能测试逐项检查独立开关，对依赖、冲突和桌面选择保留局部组合覆盖。

部署前，在对应平台单独构建实际输出，例如：

```sh
nix build .#darwinConfigurations.Darwin.system --no-link
nix build .#homeConfigurations.ArchLinux.activationPackage --no-link
nix build .#nixosConfigurations.NixOS-Pad.config.system.build.toplevel --no-link
```

跨平台构建需要相应的远程 builder；这些命令不会切换当前系统。

## 许可证

[Apache License 2.0](LICENSE) · Copyright © 2026 HsingYun
