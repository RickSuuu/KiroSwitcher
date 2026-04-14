import Cocoa

// MARK: - App Definition
struct AppDefinition {
    let name: String           // Display name
    let processName: String    // NSRunningApplication.localizedName
    let executableMatch: String // Path substring to match
    let bundleIdMatch: String  // Bundle ID substring to match
    let titleSeparator: String // How to split window title
    let projectPosition: ProjectPosition // Where the project name sits
    let indicatorColor: NSColor // Active tab indicator color
    
    enum ProjectPosition {
        case last   // "... — ProjectName" (Kiro style)
        case first  // "ProjectName – file.java [module]" (IDEA style)
    }
    
    func extractProject(from title: String) -> String {
        let parts = title.components(separatedBy: titleSeparator)
        guard parts.count >= 2 else { return title }
        switch projectPosition {
        case .last:
            return parts.last!.trimmingCharacters(in: .whitespaces)
        case .first:
            return parts.first!.trimmingCharacters(in: .whitespaces)
        }
    }
}

let supportedApps: [AppDefinition] = [
    AppDefinition(
        name: "Kiro",
        processName: "Kiro",
        executableMatch: "Kiro.app/Contents/MacOS",
        bundleIdMatch: "kiro",
        titleSeparator: " — ",
        projectPosition: .last,
        indicatorColor: NSColor(red: 0.30, green: 0.56, blue: 1.0, alpha: 1)
    ),
    AppDefinition(
        name: "IDEA",
        processName: "IntelliJ IDEA",
        executableMatch: "IntelliJ IDEA",
        bundleIdMatch: "intellij",
        titleSeparator: " \u{2013} ",
        projectPosition: .first,
        indicatorColor: NSColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1)
    ),
]

// MARK: - Icon Cache (reads real app icon from running process)
class AppIconCache {
    static let shared = AppIconCache()
    private var cache: [String: NSImage] = [:]
    
    func icon(for appDef: AppDefinition, size: CGFloat = 18) -> NSImage? {
        if let cached = cache[appDef.name] { return cached }
        
        for app in NSWorkspace.shared.runningApplications {
            let nameMatch = app.localizedName == appDef.processName
            let execMatch = app.executableURL?.path.contains(appDef.executableMatch) == true
            let bundleMatch = (app.bundleIdentifier ?? "").lowercased().contains(appDef.bundleIdMatch)
            if nameMatch || execMatch || bundleMatch, let icon = app.icon {
                icon.size = NSSize(width: size, height: size)
                cache[appDef.name] = icon
                return icon
            }
        }
        return nil
    }
}

// MARK: - Window Info
struct WindowInfo {
    let project: String
    let appDef: AppDefinition
    let ax: AXUIElement
    
    var uniqueKey: String { "\(appDef.name):\(project)" }
}

// MARK: - Window Manager
class MultiWindowManager {

    /// Find PID for a supported app
    private func findPID(for appDef: AppDefinition) -> pid_t? {
        for app in NSWorkspace.shared.runningApplications {
            let nameMatch = app.localizedName == appDef.processName
            let execMatch = app.executableURL?.path.contains(appDef.executableMatch) == true
            let bundleMatch = (app.bundleIdentifier ?? "").lowercased().contains(appDef.bundleIdMatch)
            if nameMatch || execMatch || bundleMatch {
                return app.processIdentifier
            }
        }
        return nil
    }
    
    /// Get all windows across all supported apps
    func getAllWindows() -> [WindowInfo] {
        var results: [WindowInfo] = []
        var seen = Set<String>()
        
        for appDef in supportedApps {
            guard let pid = findPID(for: appDef) else { continue }
            let appRef = AXUIElementCreateApplication(pid)
            var wRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &wRef) == .success,
                  let axWins = wRef as? [AXUIElement] else { continue }
            
            for ax in axWins {
                var tRef: CFTypeRef?
                AXUIElementCopyAttributeValue(ax, kAXTitleAttribute as CFString, &tRef)
                let title = (tRef as? String) ?? ""
                guard !title.isEmpty else { continue }
                
                // Filter out small windows (dialogs, popups)
                var sRef: CFTypeRef?
                AXUIElementCopyAttributeValue(ax, kAXSizeAttribute as CFString, &sRef)
                var sz = CGSize.zero
                if let v = sRef { AXValueGetValue(v as! AXValue, .cgSize, &sz) }
                guard sz.width > 400 && sz.height > 300 else { continue }
                
                let project = appDef.extractProject(from: title)
                let key = "\(appDef.name):\(project)"
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                results.append(WindowInfo(project: project, appDef: appDef, ax: ax))
            }
        }
        return results
    }
    
    /// Get the focused window info for the frontmost supported app
    func getFocusedWindowFrame() -> (info: WindowInfo, frame: CGRect)? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        
        // Find which supported app is frontmost
        guard let appDef = supportedApps.first(where: { def in
            let nameMatch = frontApp.localizedName == def.processName
            let execMatch = frontApp.executableURL?.path.contains(def.executableMatch) == true
            let bundleMatch = (frontApp.bundleIdentifier ?? "").lowercased().contains(def.bundleIdMatch)
            return nameMatch || execMatch || bundleMatch
        }) else { return nil }
        
        guard let pid = findPID(for: appDef) else { return nil }
        let appRef = AXUIElementCreateApplication(pid)
        var fRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &fRef) == .success else { return nil }
        let ax = fRef as! AXUIElement
        
        var tRef: CFTypeRef?
        AXUIElementCopyAttributeValue(ax, kAXTitleAttribute as CFString, &tRef)
        let title = (tRef as? String) ?? ""
        
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        AXUIElementCopyAttributeValue(ax, kAXPositionAttribute as CFString, &posRef)
        AXUIElementCopyAttributeValue(ax, kAXSizeAttribute as CFString, &sizeRef)
        var pt = CGPoint.zero
        var sz = CGSize.zero
        if let p = posRef { AXValueGetValue(p as! AXValue, .cgPoint, &pt) }
        if let s = sizeRef { AXValueGetValue(s as! AXValue, .cgSize, &sz) }
        guard sz.width > 400 else { return nil }
        
        let project = appDef.extractProject(from: title)
        let info = WindowInfo(project: project, appDef: appDef, ax: ax)
        return (info, CGRect(origin: pt, size: sz))
    }
    
    /// Tile all windows evenly across the screen
    func tileAllWindows() {
        let windows = getAllWindows()
        guard !windows.isEmpty else { return }
        
        // Use the screen where the mouse cursor is (or main screen)
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens[0]
        let visibleFrame = screen.visibleFrame
        
        // Convert NS coords (bottom-left origin) to CG coords (top-left origin)
        let primaryH = NSScreen.screens.first?.frame.height ?? screen.frame.height
        
        let count = windows.count
        let (cols, rows) = bestGrid(for: count)
        
        let cellW = visibleFrame.width / CGFloat(cols)
        let cellH = visibleFrame.height / CGFloat(rows)
        
        for (i, win) in windows.enumerated() {
            let col = i % cols
            let row = i / cols
            
            // NS coordinates for the cell
            let nsX = visibleFrame.origin.x + CGFloat(col) * cellW
            let nsY = visibleFrame.origin.y + visibleFrame.height - CGFloat(row + 1) * cellH
            
            // Convert to CG coordinates (top-left origin)
            let cgX = nsX
            let cgY = primaryH - nsY - cellH
            
            var position = CGPoint(x: cgX, y: cgY)
            var size = CGSize(width: cellW, height: cellH)
            
            if let posVal = AXValueCreate(.cgPoint, &position),
               let sizeVal = AXValueCreate(.cgSize, &size) {
                AXUIElementSetAttributeValue(win.ax, kAXPositionAttribute as CFString, posVal)
                AXUIElementSetAttributeValue(win.ax, kAXSizeAttribute as CFString, sizeVal)
            }
        }
        
        // Raise all windows so they're visible
        for win in windows {
            AXUIElementPerformAction(win.ax, kAXRaiseAction as CFString)
        }
    }
    
    /// Calculate the best grid layout (cols x rows) for N windows
    private func bestGrid(for count: Int) -> (cols: Int, rows: Int) {
        switch count {
        case 1: return (1, 1)
        case 2: return (2, 1)
        case 3: return (3, 1)  // 3 columns side by side for code editors
        case 4: return (2, 2)
        case 5, 6: return (3, 2)
        case 7, 8: return (4, 2)
        case 9: return (3, 3)
        default:
            let cols = Int(ceil(sqrt(Double(count))))
            let rows = Int(ceil(Double(count) / Double(cols)))
            return (cols, rows)
        }
    }
    
    /// Activate a specific window
    func activate(windowInfo: WindowInfo) {
        // Get fresh AX reference
        let allWindows = getAllWindows()
        guard let target = allWindows.first(where: { $0.uniqueKey == windowInfo.uniqueKey }) else { return }
        AXUIElementPerformAction(target.ax, kAXRaiseAction as CFString)
        
        if let pid = findPID(for: windowInfo.appDef),
           let app = NSRunningApplication(processIdentifier: pid) {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }
}


// MARK: - Floating Tab Bar
class TabBarPanel: NSPanel {
    
    let manager = MultiWindowManager()
    private var tabStack: NSStackView!
    private var windowInfos: [WindowInfo] = []
    private var activeKey: String? = nil
    private var refreshTimer: Timer?
    private var displayLink: CVDisplayLink?
    private let barHeight: CGFloat = 36
    private var lastKiroFrame: CGRect = .zero
    
    init() {
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: 800, height: 36),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        hidesOnDeactivate = false
        
        setupUI()
        reloadWindows()
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.reloadWindows()
        }
        
        startDisplayLink()
    }
    
    private func startDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let dl = displayLink else { return }
        
        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo -> CVReturn in
            let panel = Unmanaged<TabBarPanel>.fromOpaque(userInfo!).takeUnretainedValue()
            DispatchQueue.main.async {
                panel.followActiveWindow()
            }
            return kCVReturnSuccess
        }
        
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(dl, callback, pointer)
        CVDisplayLinkStart(dl)
    }
    
    deinit {
        if let dl = displayLink { CVDisplayLinkStop(dl) }
    }
    
    private func setupUI() {
        let bg = NSVisualEffectView(frame: .zero)
        bg.material = .titlebar
        bg.blendingMode = .behindWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 0
        bg.translatesAutoresizingMaskIntoConstraints = false
        contentView!.addSubview(bg)
        
        tabStack = NSStackView()
        tabStack.orientation = .horizontal
        tabStack.spacing = 0
        tabStack.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(tabStack)
        
        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: contentView!.topAnchor),
            bg.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor),
            bg.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor),
            
            tabStack.topAnchor.constraint(equalTo: bg.topAnchor),
            tabStack.bottomAnchor.constraint(equalTo: bg.bottomAnchor),
            tabStack.centerXAnchor.constraint(equalTo: bg.centerXAnchor),
            tabStack.leadingAnchor.constraint(greaterThanOrEqualTo: bg.leadingAnchor, constant: 4),
        ])
    }

    func reloadWindows() {
        let windows = manager.getAllWindows()
        let keys = windows.map { $0.uniqueKey }
        let oldKeys = windowInfos.map { $0.uniqueKey }
        guard keys != oldKeys else { return }
        windowInfos = windows
        rebuildTabs()
    }
    
    private func rebuildTabs() {
        tabStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if windowInfos.isEmpty {
            let label = NSTextField(labelWithString: "  ⚡ 等待 IDE 窗口...  ")
            label.font = .systemFont(ofSize: 12)
            label.textColor = NSColor(white: 0.5, alpha: 1)
            tabStack.addArrangedSubview(label)
            return
        }
        
        for (i, info) in windowInfos.enumerated() {
            let isActive = (info.uniqueKey == activeKey)
            
            let container = NSView()
            container.wantsLayer = true
            container.translatesAutoresizingMaskIntoConstraints = false
            
            if isActive {
                container.layer?.backgroundColor = NSColor(white: 1, alpha: 0.12).cgColor
            }
            
            // Active indicator
            if isActive {
                let ind = NSView()
                ind.wantsLayer = true
                ind.layer?.backgroundColor = info.appDef.indicatorColor.cgColor
                ind.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(ind)
                NSLayoutConstraint.activate([
                    ind.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                    ind.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
                    ind.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
                    ind.heightAnchor.constraint(equalToConstant: 2),
                ])
            }
            
            // Separator
            if i > 0 {
                let sep = NSView()
                sep.wantsLayer = true
                sep.layer?.backgroundColor = NSColor(white: 0.35, alpha: 0.3).cgColor
                sep.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(sep)
                NSLayoutConstraint.activate([
                    sep.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    sep.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
                    sep.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
                    sep.widthAnchor.constraint(equalToConstant: 1),
                ])
            }
            
            // Icon + Label
            let tabContent = NSStackView()
            tabContent.orientation = .horizontal
            tabContent.spacing = 5
            tabContent.alignment = .centerY
            tabContent.translatesAutoresizingMaskIntoConstraints = false
            
            // App icon from running process
            let iconSize: CGFloat = 18
            if let appIcon = AppIconCache.shared.icon(for: info.appDef, size: iconSize) {
                let iv = NSImageView(image: appIcon)
                iv.translatesAutoresizingMaskIntoConstraints = false
                iv.imageScaling = .scaleProportionallyUpOrDown
                NSLayoutConstraint.activate([
                    iv.widthAnchor.constraint(equalToConstant: iconSize),
                    iv.heightAnchor.constraint(equalToConstant: iconSize),
                ])
                tabContent.addArrangedSubview(iv)
            }
            
            let label = NSTextField(labelWithString: info.project)
            label.font = .systemFont(ofSize: 13, weight: isActive ? .bold : .medium)
            label.textColor = isActive ? .white : NSColor(white: 0.65, alpha: 1)
            label.lineBreakMode = .byTruncatingTail
            tabContent.addArrangedSubview(label)
            
            // Wrap in a clickable button area
            let btn = NSButton(frame: .zero)
            btn.tag = i
            btn.target = self
            btn.action = #selector(tabClicked(_:))
            btn.isBordered = false
            btn.title = ""
            btn.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(tabContent)
            container.addSubview(btn)
            
            NSLayoutConstraint.activate([
                container.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
                tabContent.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                tabContent.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                tabContent.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                btn.topAnchor.constraint(equalTo: container.topAnchor),
                btn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                btn.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                btn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])
            
            tabStack.addArrangedSubview(container)
        }
        
        // Add tile button at the end (only when there are 2+ windows)
        if windowInfos.count >= 2 {
            let tileBtn = NSButton(frame: .zero)
            tileBtn.title = "⊞"
            tileBtn.toolTip = "平铺所有窗口"
            tileBtn.font = .systemFont(ofSize: 16)
            tileBtn.isBordered = false
            tileBtn.target = self
            tileBtn.action = #selector(tileClicked)
            tileBtn.translatesAutoresizingMaskIntoConstraints = false
            
            let tileContainer = NSView()
            tileContainer.wantsLayer = true
            tileContainer.translatesAutoresizingMaskIntoConstraints = false
            
            // Separator before tile button
            let sep = NSView()
            sep.wantsLayer = true
            sep.layer?.backgroundColor = NSColor(white: 0.35, alpha: 0.3).cgColor
            sep.translatesAutoresizingMaskIntoConstraints = false
            tileContainer.addSubview(sep)
            tileContainer.addSubview(tileBtn)
            
            NSLayoutConstraint.activate([
                tileContainer.widthAnchor.constraint(equalToConstant: 40),
                sep.leadingAnchor.constraint(equalTo: tileContainer.leadingAnchor),
                sep.topAnchor.constraint(equalTo: tileContainer.topAnchor, constant: 8),
                sep.bottomAnchor.constraint(equalTo: tileContainer.bottomAnchor, constant: -8),
                sep.widthAnchor.constraint(equalToConstant: 1),
                tileBtn.centerXAnchor.constraint(equalTo: tileContainer.centerXAnchor, constant: 2),
                tileBtn.centerYAnchor.constraint(equalTo: tileContainer.centerYAnchor),
            ])
            
            tabStack.addArrangedSubview(tileContainer)
        }
    }
    
    @objc private func tabClicked(_ sender: NSButton) {
        let idx = sender.tag
        guard idx >= 0 && idx < windowInfos.count else { return }
        let info = windowInfos[idx]
        activeKey = info.uniqueKey
        rebuildTabs()
        manager.activate(windowInfo: info)
    }
    
    @objc private func tileClicked() {
        manager.tileAllWindows()
        // Reset frame tracking so the bar repositions after tiling
        lastKiroFrame = .zero
    }
    
    // MARK: - Follow Active Window
    private func followActiveWindow() {
        // Show when any supported app is frontmost
        guard let focusResult = manager.getFocusedWindowFrame() else {
            if isVisible { orderOut(nil) }
            return
        }
        
        if !isVisible { orderFront(nil) }
        
        // Update menu bar icon to match current IDE
        if let statusBtn = (NSApp.delegate as? AppDelegate)?.statusItem?.button {
            if let icon = AppIconCache.shared.icon(for: focusResult.info.appDef, size: 18) {
                icon.isTemplate = false
                statusBtn.image = icon
            }
        }
        
        let kiroFrame = focusResult.frame
        if kiroFrame == lastKiroFrame { return }
        lastKiroFrame = kiroFrame
        
        // Update active highlight
        let newKey = focusResult.info.uniqueKey
        if newKey != activeKey {
            activeKey = newKey
            rebuildTabs()
        }
        
        // Convert CG coords (top-left origin) to NS coords (bottom-left origin)
        let primaryH = NSScreen.screens.first?.frame.height ?? 900
        
        let barX = kiroFrame.origin.x
        let barW = kiroFrame.width
        
        // NS Y of the window's top edge
        let windowTopNSY = primaryH - kiroFrame.origin.y
        // NS Y of the window's bottom edge
        let windowBottomNSY = primaryH - (kiroFrame.origin.y + kiroFrame.height)
        
        // Check if there's enough space above the window for the tab bar
        let menuBarMaxY = NSScreen.main?.visibleFrame.maxY ?? (primaryH - 25)
        
        let barY: CGFloat
        if windowTopNSY + barHeight > menuBarMaxY {
            // Not enough space above (fullscreen or near top) — place bar at the bottom of the window
            barY = windowBottomNSY
        } else {
            // Normal case — place bar above the window
            barY = windowTopNSY
        }
        
        if !isVisible { orderFront(nil) }
        setFrame(CGRect(x: barX, y: barY, width: barW, height: barHeight), display: false, animate: false)
    }
}


// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: TabBarPanel?
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(opts) {
            let a = NSAlert()
            a.messageText = "需要辅助功能权限"
            a.informativeText = "请在 系统设置 > 隐私与安全 > 辅助功能 中授权，然后重启应用。"
            a.runModal()
        }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem?.button {
            var foundIcon = false
            for appDef in supportedApps {
                if let icon = AppIconCache.shared.icon(for: appDef, size: 18) {
                    icon.isTemplate = false
                    btn.image = icon
                    foundIcon = true
                    break
                }
            }
            if !foundIcon { btn.title = "DS" }
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "⊞ 平铺所有窗口", action: #selector(tileWindows), keyEquivalent: "t"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "显示/隐藏", action: #selector(toggle), keyEquivalent: "k"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
        
        panel = TabBarPanel()
        panel?.orderFront(nil)
    }
    
    @objc func tileWindows() {
        let mgr = panel?.manager ?? MultiWindowManager()
        mgr.tileAllWindows()
        panel?.reloadWindows()
    }
    @objc func toggle() {
        if panel?.isVisible == true { panel?.orderOut(nil) }
        else { panel?.orderFront(nil) }
    }
    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
