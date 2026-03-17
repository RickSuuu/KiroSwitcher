# DevSwitcher

A lightweight macOS floating tab bar for quickly switching between multiple **Kiro** and **IntelliJ IDEA** editor windows.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

---

## Why?

When you have many microservices open in separate Kiro / IDEA windows, switching between them is painful. DevSwitcher adds a Chrome-like tab bar that floats above your editor windows, letting you switch projects with a single click — even across different IDEs.

## Features

- **Floating tab bar** — sits above the active editor window, auto-follows when you move or resize
- **Multi-IDE support** — discovers both Kiro and IntelliJ IDEA windows with real app icons
- **Instant switch** — click a tab to bring that window to front, works cross-IDE
- **Color-coded indicators** — blue for Kiro, orange for IDEA
- **Smart tracking** — synced to display refresh rate (60/120Hz) via CVDisplayLink
- **Auto hide & show** — hides when no supported IDE is active, reappears when you switch back
- **Dynamic menu bar icon** — changes to match the currently active IDE

## Supported IDEs

| IDE | Indicator Color | Title Format |
|-----|----------------|--------------|
| Kiro | Blue | `... — ProjectName` |
| IntelliJ IDEA | Orange | `ProjectName – file.java [module]` |

Adding more IDEs is easy — just add an `AppDefinition` to the `supportedApps` array in `main.swift`.

## Requirements

- macOS 13.0+
- Swift 5.9+
- Accessibility permission (prompted on first launch)

## Build & Run

```bash
swift build -c release
bash bundle.sh
open KiroSwitcher.app
```

## First Launch

1. Run the app — it will prompt for Accessibility permission
2. Go to **System Settings > Privacy & Security > Accessibility**
3. Enable **KiroSwitcher**
4. Restart the app

## Adding More IDEs

Edit `supportedApps` in `Sources/main.swift`:

```swift
AppDefinition(
    name: "VSCode",
    processName: "Code",
    executableMatch: "Visual Studio Code.app",
    bundleIdMatch: "vscode",
    titleSeparator: " — ",
    projectPosition: .last,
    indicatorColor: NSColor(red: 0.0, green: 0.47, blue: 0.83, alpha: 1)
)
```

## License

MIT

---

# DevSwitcher（中文）

轻量级 macOS 浮动标签栏，用于在多个 **Kiro** 和 **IntelliJ IDEA** 编辑器窗口之间快速切换。

## 为什么需要？

当你有很多微服务分别在不同的 Kiro / IDEA 窗口中打开时，切换起来非常痛苦。DevSwitcher 在编辑器窗口上方添加一个类似 Chrome 的浮动标签栏，点击标签即可一键切换项目，支持跨 IDE 切换。

## 功能

- **浮动标签栏** — 悬浮在当前编辑器窗口上方，移动或缩放时自动跟随
- **多 IDE 支持** — 同时检测 Kiro 和 IntelliJ IDEA 窗口，显示真实应用图标
- **即时切换** — 点击标签即可将对应窗口切到前台，支持跨 IDE
- **颜色区分** — 蓝色指示条 = Kiro，橙色 = IDEA
- **智能跟踪** — 通过 CVDisplayLink 与屏幕刷新率同步（60/120Hz）
- **自动显隐** — 非 IDE 前台时自动隐藏，切回来时自动出现
- **动态菜单栏图标** — 跟随当前前台 IDE 实时切换

## 支持的 IDE

| IDE | 指示条颜色 | 标题格式 |
|-----|----------|---------|
| Kiro | 蓝色 | `... — 项目名` |
| IntelliJ IDEA | 橙色 | `项目名 – 文件名 [模块名]` |

添加更多 IDE 很简单，只需在 `main.swift` 的 `supportedApps` 数组中添加一个 `AppDefinition`。

## 环境要求

- macOS 13.0+
- Swift 5.9+
- 辅助功能权限（首次启动时会提示授权）

## 构建与运行

```bash
swift build -c release
bash bundle.sh
open KiroSwitcher.app
```

## 首次启动

1. 运行应用，会弹出辅助功能权限请求
2. 前往 **系统设置 > 隐私与安全 > 辅助功能**
3. 启用 **KiroSwitcher**
4. 重启应用

## 许可证

MIT
