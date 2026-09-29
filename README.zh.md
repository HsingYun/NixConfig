# NixConfig

[English](README.md) · 简体中文

面向 NixOS、WSL、macOS 和 Linux 的声明式系统与用户配置。各机器共享基础配置，独立选择功能并设置差异配置。

- NixOS 桌面：GNOME 或 Niri + DankMaterialShell。
- 应用配置：Git、Zsh、GPG、Ghostty 和 mpv。
- 开发工具（`devel`）：Clang/LLVM、GCC、GDB/LLDB、构建工具、Python、Go、Node.js/TypeScript、OpenJDK、Rust/Cargo，以及 Git LFS、Protobuf、Abseil、coreutils 和 Telnet。
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
  ghostty = true;
};
```

功能默认值与平台支持见[功能目录](nix/lib/features/catalog.nix)，仅需声明与默认值不同的开关。关闭功能会撤去本仓库的对应定制，不阻止其他模块提供同一能力，也不删除应用数据。

软件安装统一通过软件层处理。Host 选择 `packageManager` 和 `features`；主机独有的软件在 `packageManager.externalPkg` 中使用对应包管理器的原生包名声明：

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

NixOS/WSL 默认使用 Nix；Darwin 默认优先 Homebrew，缺少可用实现或不能满足功能能力时回退 Nix。独立 Linux 需明确指定包管理器；Arch 使用 `pacman`，AUR 包由 yay 安装。`apt` 等尚未实现的后端会明确报错。选择依据来自软件目录，不依赖本机安装状态。

Feature 同时声明配置与软件需求，依赖自动合并去重。例如 Ghostty 需要 Maple Mono；关闭 Ghostty 后，中文功能仍可保留同一字体。Niri 通过 `xdg-terminal-exec` 启动终端，不再隐式选择 Ghostty。

`externalPkg` 中与已启用功能重复的软件由统一层合并，遵循功能选定的来源及包装配置。选定的 Nix 命令优先于旧的原生安装。需要替换功能的 Nix 包时，在 Home Manager 配置中使用 `software.packageOverrides.<软件标识>`，安装清单与模块配置会同步更新。Arch、PC、Pad 已补入对应包管理器的额外工具，跳过 macOS 专属包。

`vim` 默认启用，安装所选来源的 Vim，并从 [nix/assets/vimrc](nix/assets/vimrc) 管理 `~/.vimrc`；插件仍由 vim-plug 安装与更新。首次应用前，请备份已有且未由 Home Manager 管理的 `~/.vimrc`。现有 PC、Pad 使用 Nix 应用；Darwin 优先使用 Homebrew，并由统一层配置相应 PATH。

关闭 feature 会撤去其软件需求；共享需求仍保留。Homebrew 保持 `cleanup = "none"`，因此撤去清单项不会自动卸载现有软件。Zsh、GPG agent 和 mpv 插件等要求 Nix 包路径的集成会显式声明能力约束，解析结果会说明回退原因。

可查看每台主机的软件来源：

```sh
nix eval --json .#lib.softwarePlans.Darwin
nix eval --json .#lib.softwareManifests.Darwin
```

软件目录、能力接口及后端扩展方式见[软件架构](docs/software.md)。

DMS 使用上游 Home Manager 选项 `programs.dank-material-shell.settings` 和 `.session`。非空值以声明式方式管理对应 JSON 文件（只读）；将对应选项设为 `lib.mkForce { }`，可交由 DMS 管理该文件。应用列表通过 `desktop.launcher.hiddenEntries` 配置隐藏名单，仅处理实际存在的桌面入口。

原生 NixOS 默认启用 `network`，使用 systemd-networkd 与 systemd-resolved；桌面功能共享该能力，默认使用 NetworkManager 与 systemd-resolved。在 `system.nix` 中设置 `networking.networkmanager.enable`，可独立选择 NetworkManager（`true`）或 networkd（`false`）。WSL、macOS 和独立 Home Manager 保留所属平台的网络管理方式。

新增机器时，将 [nix/templates/](nix/templates/) 中对应平台的目录复制到 `hosts/<机器名>/`，补齐配置与 stateVersion，再注册到 `hosts/default.nix`。原生 NixOS 还需配置硬件与引导程序。

## 目录结构

```text
flake.nix      依赖与共享用户信息
hosts/         机器配置
nix/
  modules/     系统、用户与功能模块
  templates/   各平台机器模板
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

CI 在 x86_64 Linux 和 Apple Silicon macOS 上分别执行原生检查。`host-*` 检查会求值完整主机输出及其断言，但不会构建或激活整台机器。功能测试逐项检查独立开关，对依赖、冲突和桌面选择保留局部组合覆盖。

部署前，在对应平台单独构建实际输出，例如：

```sh
nix build .#darwinConfigurations.Darwin.system --no-link
nix build .#homeConfigurations.ArchLinux.activationPackage --no-link
nix build .#nixosConfigurations.NixOS-Pad.config.system.build.toplevel --no-link
```

跨平台构建需要相应的远程 builder；这些命令不会切换当前系统。

## 许可证

[Apache License 2.0](LICENSE) · Copyright © 2026 HsingYun
