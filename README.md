<p align="center">
  <img src="icon_source.png" width="128" height="128" alt="NTFS Mac Icon">
</p>

<h1 align="center">NTFS Mac</h1>

<p align="center">
  免费开源的 macOS 菜单栏工具，让你的 Mac 轻松读写 NTFS 格式外置硬盘。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.9-orange" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
</p>

---

## 功能特性

- **自动检测** — 插入 NTFS 磁盘后自动识别并弹出通知
- **一键读写挂载** — 基于 macFUSE + NTFS-3G，无需命令行操作
- **安全卸载** — 一键安全弹出已挂载的磁盘
- **菜单栏常驻** — 轻量菜单栏 App，不占用 Dock 栏
- **管理窗口** — 可选的详细管理窗口，查看磁盘信息
- **安装引导** — 内置依赖检测和分步安装引导，自动适配 Apple Silicon / Intel

## 安装

### 1. 安装依赖

NTFS Mac 依赖 [macFUSE](https://osxfuse.github.io/) 和 [NTFS-3G](https://github.com/tuxera/ntfs-3g) 提供底层 NTFS 读写能力。

#### 通过 Homebrew 安装（推荐）

```bash
# 安装 macFUSE
brew install --cask macfuse
```

> **重要**：安装 macFUSE 后需要：
> 1. 打开「系统设置 → 隐私与安全性」，允许系统扩展
> 2. 重启电脑

```bash
# 安装 NTFS-3G
# Apple Silicon Mac（M1/M2/M3/M4）：
brew install gromgit/fuse/ntfs-3g-mac

# Intel Mac：
brew install ntfs-3g
```

#### 手动安装

1. 从 [macFUSE 官网](https://osxfuse.github.io/) 下载并安装 macFUSE
2. 从源码编译 NTFS-3G：`brew install --build-from-source ntfs-3g`

### 2. 安装 NTFS Mac

从 [Releases](https://github.com/user/ntfs-mac/releases) 页面下载最新的 `NTFSMac.dmg`，打开后将应用拖入 `Applications` 文件夹即可。

## 使用方法

1. 启动 NTFS Mac，图标出现在菜单栏
2. 如果依赖未安装，菜单栏底部会出现提示，点击进入**安装引导**
3. 插入 NTFS 格式外置硬盘或 U 盘
4. 收到系统通知，点击「以读写模式挂载」
5. 也可以在菜单栏或主窗口中手动操作挂载/卸载
6. 使用完毕后，点击「安全卸载」弹出磁盘

## 从源码构建

### 前置条件

- macOS 14.0 (Sonoma) 或更高版本
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### 构建步骤

```bash
# 克隆项目
git clone https://github.com/user/ntfs-mac.git
cd ntfs-mac

# 安装 XcodeGen（如未安装）
brew install xcodegen

# 生成 Xcode 项目
xcodegen generate

# 方式一：在 Xcode 中运行
open NTFSMac.xcodeproj
# 按 ⌘R 运行

# 方式二：命令行编译
xcodebuild build \
  -project NTFSMac.xcodeproj \
  -scheme NTFSMac \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=NO
```

### 打包 DMG

```bash
bash scripts/build.sh
# 输出：build/NTFSMac.dmg
```

## 项目结构

```text
NTFSMac/
├── NTFSMacApp.swift              # App 入口 + AppState
├── Assets.xcassets/              # 应用图标资源
├── Models/
│   └── NTFSDisk.swift            # 磁盘数据模型 + 依赖状态
├── Services/
│   ├── DiskManager.swift         # 核心：磁盘检测、挂载、卸载、依赖检测
│   └── NotificationManager.swift # 系统通知管理
├── Views/
│   ├── MenuBarView.swift         # 菜单栏下拉面板
│   ├── MainWindowView.swift      # 主窗口（详细管理）
│   ├── SetupGuideView.swift      # 依赖安装引导
│   └── DiskRowView.swift         # 磁盘行组件
├── Info.plist
└── NTFSMac.entitlements
```

## 技术栈

| 组件 | 技术 |
|------|------|
| 语言 | Swift 5.9 |
| UI 框架 | SwiftUI (MenuBarExtra + Window) |
| 磁盘检测 | DiskArbitration Framework |
| NTFS 读写 | macFUSE + NTFS-3G |
| 系统通知 | UserNotifications Framework |
| 项目管理 | XcodeGen |

## 系统要求

- macOS 14.0 (Sonoma) 或更高版本
- macFUSE >= 4.x
- NTFS-3G

## License

[MIT](LICENSE)
