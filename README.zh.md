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

`platform = "arch"` 选择 Arch 适配，`system = "x86_64-linux"` 仍表示 Nix 的 CPU/操作系统目标。平台定义统一位于 [nix/lib/hosts/platforms.nix](nix/lib/hosts/platforms.nix)，不再接受旧的 `platform = "linux"` 名称。

共享体验定义于 [nix/lib/hosts/profiles.nix](nix/lib/hosts/profiles.nix)，各主机只保留桌面选择和硬件差异：

| 主机 | 默认体验 |
| --- | --- |
| ArchLinux | Niri + DMS + greetd，也安装 GNOME；包优先 pacman/AUR |
| NixOS-PC | 同样使用 Niri + DMS + greetd，也安装 GNOME；hardware 仍为占位 |
| NixOS-Pad | GNOME + GDM，屏幕旋转、屏幕键盘和触屏方向调整 |
| Darwin | 共享命令行、开发工具、GPG、Ghostty、Chrome、VS Code 和 mpv；保留 macOS 桌面 |
| NixOS-WSL | 共享命令行、开发和 GPG/智能卡，使用终端 pinentry；不启用桌面和中文输入法 |

PC / Arch 改用 GNOME 时，将 `preferences.desktop = "gnome"; preferences.loginManager = "gdm";` 即可；无需删除 Niri 配置。Pad 如需 Niri，启用 `desktop.niri` / `desktop.dms` 并改变同一组 preferences。

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

软件安装统一通过软件层处理。Host 选择 `packageManager` 和 `features`；主机独有的软件在 `packageManager.externalPkg` 中使用对应包管理器的原生包名声明：

```nix
packageManager = {
  type = "homebrew";
  externalPkg.brews = [ "watch" ];
};
features = {
  ghostty.enable = true;
  vim.enable = true;
  chrome.enable = true;
};
```

NixOS/WSL 默认使用 Nix；Darwin 默认优先 Homebrew，缺少可用实现或不能满足功能能力时回退 Nix。Arch 默认使用 `pacman`，AUR 包由 yay 安装。`apt` 等尚未实现的后端会明确报错。选择依据来自软件目录，不依赖本机安装状态。

Feature 同时声明配置与软件需求，依赖自动合并去重。例如 Ghostty 需要 Maple Mono；关闭 Ghostty 后，中文功能仍可保留同一字体。Niri 通过 `xdg-terminal-exec` 启动终端，不再隐式选择 Ghostty。

`features.vscode` 会安装 Maple Mono，并在首次应用时补充 VS Code 编辑器和集成终端的字体设置。已有设置和 JSONC 注释保留；初始化后由用户管理，后续应用、关闭或重新启用 feature 都不会重设。可通过 `features.vscode.initialSettings` 自定义首次填入的设置。初始化标记位于 `$XDG_STATE_HOME/nixconfig/vscode-initialized`（默认 `~/.local/state` 下）；不支持自动修改命名 Profile、便携版或远程 VS Code 的设置。

`externalPkg` 中与已启用功能重复的软件由统一层合并，遵循功能选定的来源及包装配置。选定的 Nix 命令优先于旧的原生安装。需要替换功能的 Nix 包时，在 Home Manager 配置中使用 `software.packageOverrides.<软件标识>`，安装清单与模块配置会同步更新。Arch、PC、Pad、Darwin 的共享工具已抽为 `features.commonTools.enable = true;`：aria2、GnuPG、GnuTLS、Graphviz、ncurses、OpenSSL、pinentry、rsync、SQLite、xz、zlib、zstd。它不隐式开启 GPG 配置，沿用所选包管理器优先、Nix 回退及能力约束合并规则。Linux 的 procps 也归入 commonTools。主机 `externalPkg` 只保留差异项，例如 Darwin 的 watch 和通用 pinentry；WSL 通过所选 pinentry 包使用终端交互。

`vim` 默认启用，安装所选来源的 Vim，并从 [nix/assets/vimrc](nix/assets/vimrc) 管理 `~/.vimrc`；插件仍由 vim-plug 安装与更新。首次应用前，请备份已有且未由 Home Manager 管理的 `~/.vimrc`。现有 PC、Pad 使用 Nix 应用；Darwin 优先使用 Homebrew，并由统一层配置相应 PATH。

关闭 feature 会撤去其软件需求；共享需求仍保留。Arch 普通关闭功能不卸载包；明确用 `software.packageOverrides` 把应用切到 Nix 时，在 Nix 包安装成功后，自动以普通 `pacman -R` 移除对应的旧原生包。不级联删除、不跳过依赖检查；仍被原生依赖使用、仍作为账户登录 shell，或仍提供活动/启用系统服务的包会使迁移停止。Homebrew 保持 `cleanup = "none"`，因此撤去清单项不会自动卸载现有软件。Zsh、GPG agent 和 mpv 插件等要求 Nix 包路径的集成会显式声明能力约束，解析结果会说明回退原因。

可查看每台主机的软件来源：

```sh
nix eval --json .#lib.softwarePlans.Darwin
nix eval --json .#lib.softwareManifests.Darwin
```

软件目录、能力接口及后端扩展方式见[软件架构](docs/software.md)。

桌面配置统一从 feature 输入：

```nix
features.desktop = {
  gnome.enable = true;
  niri.enable = true;
  dms.enable = true;
  niri.settings.layout.gaps = 12;
  gnome.settings."org/gnome/desktop/interface".clock-show-seconds = true;
  dms.settings.fontFamily = "Sans";
  launcher = {
    enable = true;
    hiddenEntries = [ "org.gnome.Tour.desktop" "org.gnome.Tecla.desktop" ];
  };
  wallpaper = {
    enable = true;
    image = /absolute/path/desktop.png;
    lockImage = /absolute/path/lock.png;
  };
};
```

`fileManager`、`keyring`、`launcher`、`wallpaper`、`printing`、`firmware` 随桌面功能默认启用，也能独立关闭。壁纸共享默认值在 `flake.nix` 的 `features.desktop.wallpaper` 中，已从 `user.wallpaper/lockWallpaper` 迁入；主机可覆盖路径，显式 `null` 表示不管理对应图片。GNOME 和 DMS 使用同一组图片，NixOS DMS 登录界面也使用 `lockImage`。单独的 Niri 不含壁纸渲染器，这里由 DMS 显示壁纸。

`features.desktop.fileManager` 统一安装 Nautilus，并将其设为默认文件管理器。`sortDirectoriesFirst`、`showHiddenFiles`、`showCreateLink`、`showDeletePermanently` 默认均为 `true`：文件夹优先、显示隐藏文件，右键菜单显示“新建链接”和“永久删除”。HM 通过 dconf 管理设置，同时兼容 GTK3/GTK4 文件选择器。Arch 使用 pacman，NixOS 使用 Nix；关闭此 feature 会同时移除受管理的 Niri `Mod+E` 快捷键，Arch 已安装的软件包保留。

`features.desktop.gnome.flatAppGrid` 默认 `true`，仅将 GNOME Overview 应用抽屉的分组列表显式设为空；它不删除分组详情或重置应用排列。设为 `false` 后不再管理该分组列表。GNOME Shell 会识别显式空列表，因此不会自动重新创建默认分组（[上游实现](https://github.com/GNOME/gnome-shell/blob/main/js/ui/appDisplay.js)）。

GNOME 的 Dash to Dock 默认固定在底部并延伸至屏幕边缘，关闭自动隐藏和智能隐藏，启用“收缩 Dash”，登录时不自动显示概览。“显示应用程序”位于最左侧。固定项按文本编辑器、文件管理器、Ghostty 排列；后两项仅在对应功能启用时添加。可通过 `features.desktop.gnome.settings` 覆盖 `org/gnome/shell` 和 `org/gnome/shell/extensions/dash-to-dock` 下的设置。

ArchLinux 主机已启用 GNOME、Niri+DMS、壁纸和应用隐藏。GNOME 按[明确的 Arch 软件包清单](nix/modules/home/features/gnome.nix)安装缺失组件，包括 GDM，但不安装整个 `gnome` 包组；仓库来源遵循本机 pacman 配置。HM 管理 GNOME 扩展 UUID 和 dconf，以原生 `niri validate` 验证配置，并将 Arch 的 DMS 用户服务启用到 Niri 会话。通过系统的 Niri 登录会话或 `niri-session` 启动，用户服务才会随会话启动。

GNOME 在 Arch 和 NixOS 都安装任务中心 `mission-center`、相机 `snapshot`、`gnome-text-editor` 和“密码与密钥”`seahorse`（NixOS 沿用官方 GNOME 模块）。终端使用独立的 Ghostty feature，不再请求 `gnome-console`；NixOS 排除旧的 GNOME Terminal、gedit、Cheese，隐藏规则也覆盖这些旧入口。

默认隐藏名单还包含 CUPS 打印管理、GNOME Tecla、Fcitx 键盘布局查看器，以及 Fcitx 5 配置入口和迁移向导：`cups.desktop`、`org.gnome.Tecla.desktop`、`kbd-layout-viewer5.desktop`、`fcitx5-configtool.desktop`、`org.fcitx.fcitx5-config-qt.desktop`、`org.fcitx.fcitx5-migrator.desktop`。仅隐藏实际存在的桌面入口，打印服务、命令行调用和输入法菜单中的配置功能保留。

`features.desktop.printing.enable` 管理 CUPS 和打印发现；`features.desktop.firmware.enable` 管理 fwupd 和 GNOME Firmware。两项在 ArchLinux 主机已启用。Arch 安装原生 CUPS、过滤器、Ghostscript、libusb、Avahi 和 fwupd，启动 `cups.socket`、Avahi 服务/socket、`fwupd-refresh.timer`；NixOS 使用官方系统模块。刷新 timer 只更新固件元数据，不自动刷写。打印机队列、专有驱动和固件更新仍按具体设备配置；网络打印机的 `.local` 名称解析沿用主机网络配置。

Arch 原生服务统一记录在 `/var/lib/nixconfig/native-systemd/`，状态由 root 管理。开启 feature 时安装缺失的包并启用所需服务；关闭时仅撤销本工程创建的启动链接，并停止原先既未启用也未运行、且不再被其他配置引用的服务。原有服务、管理员修改过的链接和共享依赖均保留，普通关闭 feature 不卸载软件包。重复应用不重复操作服务；中途失败可重试。DBus 按需激活仍由原生包提供，不会通过屏蔽服务来阻止其他软件使用它。

Arch 和 NixOS 使用相同的登录选择：GNOME 默认 GDM；Niri 默认 greetd，启用 DMS 时使用 DMS 登录界面，否则使用 tuigreet。多个候选同时启用时必须显式选择一个。Arch 主机配置为：

```nix
preferences = {
  desktop = "niri";
  loginManager = "greetd"; # GDM 用 "gdm"；不接管或手动登录用 "none"
};
```

Arch 激活时安装所选登录组件，按需写入 greetd 专用配置，并通过 sudo 启用一个登录管理器及 graphical.target。切换时替换原有服务的开机链接，不重启当前桌面会话，重启后使用新的登录入口。greetd 的专用服务覆盖使用 `/etc/greetd/nixconfig.toml`，保留原始 `/etc/greetd/config.toml`。选择 `none` 或关闭桌面 feature 不会自动禁用现有的原生登录服务；已有 PAM 规则和网络连接配置保持由主机管理。

DMS 参数使用 `features.desktop.dms.settings` 和 `.session`，映射到 HM 的同名选项。非空值将对应 JSON 文件作为只读声明式文件管理；需要由 DMS 界面保存配置时，关闭 `wallpaper` 并清空对应 feature 参数，或在 `home.nix` 中将 HM 对应选项设为 `lib.mkForce { }`。Arch 适配器管理 settings、session、clipboard JSON 和用户服务；NixOS 保留上游 HM 模块的完整接口。

隐藏默认名单固定声明于功能目录，包括 Avahi 的 `avahi-discover.desktop`、`bssh.desktop`、`bvnc.desktop`，旧 GNOME Terminal/gedit/Cheese，以及 `org.gnome.Tour.desktop`、`org.gnome.Tecla.desktop`、`org.gnome.Epiphany.desktop`、`org.gnome.Software.desktop` 以及 `htop.desktop`、`nvtop.desktop`、`cmake-gui.desktop`、`lstopo.desktop`、`jconsole-java-openjdk.desktop`、`jshell-java-openjdk.desktop` 和 vim/gvim 的入口。名单固定声明，这六个工具的入口名称已按当前 Arch 安装核对；运行时不会将扫描到的其他应用自动加入名单。`features.desktop.launcher.hiddenEntries` 可替换该列表，仅隐藏实际存在的入口，默认使用 `NoDisplay=true`，保留启动命令、关联和快捷动作。Nix 包在构建时读取，Arch 原生包在每次 HM 激活、安装软件后读取。Arch 的两种来源统一由带校验和的激活工具管理入口副本，切换来源不再与 HM 链接预检冲突；NixOS 直接使用 Home Manager 链接构建产物，不扫描宿主文件系统。关闭功能、撤销规则或源入口消失后，自动清理未被用户修改的原生副本；已有用户文件和其他符号链接会被保留。

中文配置只支持原生 Linux 桌面（Arch / NixOS），WSL 不支持该 feature。两边共享 Rime 雾凇配置：Fcitx 只有 Rime 一个条目，默认英文状态，保留个人词库；`features.chinese.englishByDefault = false;` 可改为默认中文，`.settings` 可覆盖 Fcitx 的 `inputMethod`、`globalOptions` 和 `addons`。Arch 使用原生 fcitx5、GTK/Qt 模块、fcitx5-rime 和 rime-ice-git；NixOS 使用其 Nix 运行时。GNOME 都接入 Kimpanel、XSettings 和 GNOME 专用 GTK 环境；Niri 保留 Wayland 输入支持，不全局强制 GTK_IM_MODULE。输入法由图形会话的用户服务启动，避免与 XDG autostart 重复。Arch 在关闭该功能后保留受管的自启动禁用入口，防止原生包重新启动输入法；从未启用过该功能则不改动已有入口。

Arch 桌面同时提供 NetworkManager、PipeWire/WirePlumber、蓝牙、UPower、UDisks 和 GVfs，用户音频服务由 HM 管理。如果另一套网络管理器正在运行而 NetworkManager 未运行，激活在修改前报错，不自动切断现有连接。`NetworkManager-wait-online.service` 只配置开机启用，不在应用配置时执行等待联网。

Niri、会话/portal 和 Keyring 等系统组件必须使用与宿主一致的包。Arch 拒绝这些组件的 Nix 包覆盖；NixOS Keyring 定制应使用系统级 nixpkgs overlay，确保 PAM、DBus、wrapper 和用户服务采用同一包。独立 Nix Keyring 必须关闭 `useWrappedDaemon`。

dconf 会记录接管前的值和最后写入的值；功能关闭（包括最后一个桌面功能关闭）后，只恢复仍与本工程写入值一致的设置，保留用户后续修改。应用配置时仍会写入当前明确声明的设置。

ArchLinux 已开启 `features.mpv.enable`，播放器使用 pacman 的 mpv，HM 管理 `mpv.conf`、脚本选项和 `mpv/scripts` 链接；ModernX、thumbfast 和字体保留当前锁定的 Nix 来源，不额外安装 Nix mpv。thumbfast 明确使用 `/usr/bin/mpv` 生成缩略图。脚本加载方式见 [mpv 文件布局文档](https://mpv.io/manual/stable/#files)。NixOS/macOS 保留原有 Nix 包装集成。

原生 NixOS 默认启用 `network`，使用 systemd-networkd 与 systemd-resolved；桌面功能共享该能力，默认使用 NetworkManager 与 systemd-resolved。在 `system.nix` 中设置 `networking.networkmanager.enable`，可独立选择 NetworkManager（`true`）或 networkd（`false`）。Arch 桌面通过适配器管理原生 NetworkManager；WSL、macOS 和未启用该适配器的独立 Home Manager 保留所属平台的网络管理方式。

在原生 NixOS 和独立 Linux 上，`chrome` 功能默认将 Google Chrome 设为 HTTP、HTTPS 和 HTML 的打开程序。可在 `home.nix` 中用 `xdg.mimeApps.defaultApplications` 覆盖各类型的桌面入口，或设置 `xdg.mimeApps.enable = false` 交由图形界面管理默认应用。

`chrome` 功能还默认安装 Bitwarden 扩展。在主机的 `default.nix` 中设置 `features.chrome.extensions = [ ];` 可关闭预装，或提供其他 Chrome Web Store 扩展 ID。Linux 使用 Chrome 的 `normal_installed` 策略，自动安装但允许用户禁用。NixOS 声明式管理策略文件；Arch 在 Home Manager 激活时通过 sudo 管理 `/etc/opt/chrome/policies/managed/nixconfig-extensions.json`（影响本机所有 Chrome 用户）。root 管理的记录跟踪内容、文件身份和配置所有者；拒绝接管未受管文件、覆盖管理员修改或沿软链接写入，内容未变不重写。关闭扩展或 `chrome` 后，只有未被外部修改、且无其他配置所有者需要的受管策略才会删除。macOS 使用用户目录的 External Extensions 清单，首次启动 Chrome 时可能需要确认启用。实现依据见 [Chrome 策略文档](https://support.google.com/chrome/a/answer/7517525?hl=en)和[外部扩展文档](https://developer.chrome.com/docs/extensions/how-to/distribute/install-extensions)。

GNOME Keyring 是统一的 Home Manager 桌面能力，由 [keyring.nix](nix/modules/home/shared/keyring.nix) 管理。在主机的 `default.nix` 中使用 `features.desktop.keyring.enable = true;` 启用，设为 `false` 关闭；GNOME、Niri 桌面默认启用，ArchLinux 主机也已启用。模块根据软件层选择的来源处理 user units：pacman 使用原生 `gnome-keyring-daemon.service` 和 `.socket`，分别启用到 `default.target` 和 `sockets.target`；Nix 使用随图形会话启动的用户服务。NixOS 系统层只衔接 PAM、D-Bus 和 portal。这里只启用密码与证书组件，SSH 仍由原有 agent 配置负责；登录自动解锁依赖登录管理器的 PAM 配置。

智能卡统一使用 `features.smartcard`。ArchLinux 主机显式启用，安装 `pcsclite`、`ccid`、`polkit`，由服务适配器管理 `pcscd.socket`；启用 GPG 时使用 PC/SC。普通桌面无需额外放宽 Polkit。Arch-WSL 或远程 SSH 需要后台访问时，可设置 `features.smartcard.allowBackgroundAccess = true;`，策略仅允许当前配置账户访问 PC/SC 两个动作。参见 [Arch-WSL 指南](docs/hosts.md#arch-under-wsl)和 [ArchWiki GnuPG](https://wiki.archlinux.org/title/GnuPG#Using_a_smart_card_on_a_remote_client)。关闭选项时只删除未被修改的本工程策略；硬件仍需转发到 WSL。

辅助脚本统一放在 [nix/assets/helpers](nix/assets/helpers)，功能定义留在 feature 模块，平台差异留在平台适配器。

新增机器请参见英文指南 [Creating hosts](docs/hosts.md)，其中说明各平台和 CPU 架构的配置、stateVersion 与验证方式。

## 目录结构

```text
flake.nix      依赖与共享用户信息
hosts/         机器配置
nix/
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
