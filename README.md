# ⚡ KiroSwitcher

A lightweight macOS floating tab bar for quickly switching between multiple [Kiro](https://kiro.dev) editor windows.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Why?

When you have many microservices open in separate Kiro windows, switching between them is painful. KiroSwitcher adds a Chrome-like tab bar that floats above your Kiro windows, letting you switch projects with a single click.

## Features

- 🏷️ **Floating tab bar** — sits above the active Kiro window, auto-follows when you move/resize
- 🔄 **Auto-detect** — discovers all open Kiro windows and extracts project names
- ⚡ **Instant switch** — click a tab to bring that project's Kiro window to front
- 🎯 **Smart tracking** — synced to your display refresh rate (60/120Hz) via CVDisplayLink
- 👻 **Auto hide/show** — hides when Kiro is not the active app, reappears when you switch back
- 🖥️ **Menu bar icon** — ⚡K icon for quick toggle and quit

## Requirements

- macOS 13.0+
- Swift 5.9+
- Accessibility permission (prompted on first launch)

## Build & Run

```bash
# Build
swift build -c release

# Bundle as .app
bash bundle.sh

# Run
open KiroSwitcher.app
```

## First Launch

1. Run the app — it will prompt for Accessibility permission
2. Go to **System Settings > Privacy & Security > Accessibility**
3. Enable **KiroSwitcher**
4. Restart the app

## How It Works

KiroSwitcher uses macOS Accessibility API (`AXUIElement`) to:
1. Find the Kiro process and enumerate its windows
2. Read window titles to extract project folder names
3. Track the focused window position via `CVDisplayLink`
4. Raise specific windows when you click a tab

The tab bar is an `NSPanel` with `nonactivatingPanel` style, so clicking it doesn't steal focus from Kiro.

## License

MIT
