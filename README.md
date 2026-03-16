# ⚡ KiroSwitcher

A lightweight macOS floating tab bar for quickly switching between multiple [Kiro](https://kiro.dev) editor windows.

轻量级 macOS 浮动标签栏，用于在多个 [Kiro](https://kiro.dev) 编辑器窗口之间快速切换。

![macOS](https://img.shields.io/badge/macOS-13.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

---

## Why? / 为什么需要？

When you have many microservices open in separate Kiro windows, switching between them is painful. KiroSwitcher adds a Chrome-like tab bar that floats above your Kiro windows, letting you switch projects with a single click.

当你有很多微服务分别在不同的 Kiro 窗口中打开时，切换起来非常痛苦。KiroSwitcher 在 Kiro 窗口上方添加一个类似 Chrome 的浮动标签栏，点击标签即可一键切换项目。

## Features / 功能

- 🏷️ **Floating tab bar / 浮动标签栏** — sits above the active Kiro window, auto-follows when you move or resize / 悬浮在当前 Kiro 窗口上方，移动或缩放时自动跟随
- 🔄 **Auto-detect / 自动检测** — discovers all open Kiro windows and extracts project names / 自动发现所有打开的 Kiro 窗口并提取项目名称
- ⚡ **Instant switch / 即时切换** — click a tab to bring that project's Kiro window to front / 点击标签即可将对应项目的 Kiro 窗口切到前台
- 🎯 **Smart tracking / 智能跟踪** — synced to your display refresh rate (60/120Hz) via CVDisplayLink / 通过 CVDisplayLink 与屏幕刷新率同步（60/120Hz）
- 👻 **Auto hide & show / 自动显隐** — hides when Kiro is not the active app, reappears when you switch back / Kiro 不在前台时自动隐藏，切回来时自动出现
- 🖥️ **Menu bar icon / 菜单栏图标** — ⚡K icon for quick toggle and quit / ⚡K 图标，快速切换显隐或退出

## Requirements / 环境要求

- macOS 13.0+
- Swift 5.9+
- Accessibility permission / 辅助功能权限（首次启动时会提示授权）

## Build & Run / 构建与运行

```bash
# Build / 构建
swift build -c release

# Bundle as .app / 打包为 .app
bash bundle.sh

# Run / 运行
open KiroSwitcher.app
```

## First Launch / 首次启动

1. Run the app — it will prompt for Accessibility permission / 运行应用，会弹出辅助功能权限请求
2. Go to **System Settings > Privacy & Security > Accessibility** / 前往 **系统设置 > 隐私与安全 > 辅助功能**
3. Enable **KiroSwitcher** / 启用 **KiroSwitcher**
4. Restart the app / 重启应用

## How It Works / 工作原理

KiroSwitcher uses macOS Accessibility API (`AXUIElement`) to:
1. Find the Kiro process and enumerate its windows / 找到 Kiro 进程并枚举其窗口
2. Read window titles to extract project folder names / 读取窗口标题提取项目文件夹名
3. Track the focused window position via `CVDisplayLink` / 通过 CVDisplayLink 跟踪当前窗口位置
4. Raise specific windows when you click a tab / 点击标签时将对应窗口提到前台

The tab bar is an `NSPanel` with `nonactivatingPanel` style, so clicking it doesn't steal focus from Kiro.

标签栏使用 `NSPanel` 的 `nonactivatingPanel` 样式，点击时不会抢走 Kiro 的焦点。

## License / 许可证

MIT
