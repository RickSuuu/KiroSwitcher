import Cocoa

// MARK: - Window Manager
class KiroWindowManager {
    
    var kiroPID: pid_t? {
        for app in NSWorkspace.shared.runningApplications {
            if app.localizedName == "Kiro",
               app.executableURL?.path.contains("Kiro.app/Contents/MacOS") == true {
                return app.processIdentifier
            }
        }
        return nil
    }
    
    /// Get deduplicated project list with fresh AX references
    func getProjects() -> [(name: String, ax: AXUIElement)] {
        guard let pid = kiroPID else { return [] }
        let appRef = AXUIElementCreateApplication(pid)
        var wRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &wRef) == .success,
              let axWins = wRef as? [AXUIElement] else { return [] }
        
        var results: [(String, AXUIElement)] = []
        var seen = Set<String>()
        
        for ax in axWins {
            var tRef: CFTypeRef?
            AXUIElementCopyAttributeValue(ax, kAXTitleAttribute as CFString, &tRef)
            let title = (tRef as? String) ?? ""
            guard !title.isEmpty else { continue }
            
            var sRef: CFTypeRef?
            AXUIElementCopyAttributeValue(ax, kAXSizeAttribute as CFString, &sRef)
            var sz = CGSize.zero
            if let v = sRef { AXValueGetValue(v as! AXValue, .cgSize, &sz) }
            guard sz.width > 400 && sz.height > 300 else { continue }
            
            let project = Self.extractProject(from: title)
            guard !seen.contains(project) else { continue }
            seen.insert(project)
            results.append((project, ax))
        }
        return results
    }
    
    /// Get focused window position and size
    func getFocusedWindowFrame() -> (project: String, frame: CGRect)? {
        guard let pid = kiroPID else { return nil }
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
        
        return (Self.extractProject(from: title), CGRect(origin: pt, size: sz))
    }
    
    func activate(project: String) {
        // Get fresh reference
        let projects = getProjects()
        guard let target = projects.first(where: { $0.name == project }) else { return }
        AXUIElementPerformAction(target.ax, kAXRaiseAction as CFString)
        if let pid = kiroPID, let app = NSRunningApplication(processIdentifier: pid) {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }
    
    static func extractProject(from title: String) -> String {
        let parts = title.components(separatedBy: " — ")
        return parts.count >= 2 ? parts.last!.trimmingCharacters(in: .whitespaces) : title
    }
}

// MARK: - Floating Tab Bar
class TabBarPanel: NSPanel {
    
    let manager = KiroWindowManager()
    private var tabStack: NSStackView!
    private var projectNames: [String] = []
    private var activeProject: String? = nil
    private var refreshTimer: Timer?
    private var displayLink: CVDisplayLink?
    private let barHeight: CGFloat = 36
    private var lastFrame: CGRect = .zero
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
        reloadProjects()
        
        // Refresh project list every 2s
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.reloadProjects()
        }
        
        // Use CVDisplayLink to sync with screen refresh rate (60/120Hz auto)
        startDisplayLink()
    }
    
    private func startDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let dl = displayLink else { return }
        
        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo -> CVReturn in
            let panel = Unmanaged<TabBarPanel>.fromOpaque(userInfo!).takeUnretainedValue()
            DispatchQueue.main.async {
                panel.followKiroWindow()
            }
            return kCVReturnSuccess
        }
        
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(dl, callback, pointer)
        CVDisplayLinkStart(dl)
    }
    
    deinit {
        if let dl = displayLink {
            CVDisplayLinkStop(dl)
        }
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

    func reloadProjects() {
        let projects = manager.getProjects()
        let names = projects.map { $0.name }
        guard names != projectNames else { return }
        projectNames = names
        rebuildTabs()
    }
    
    private func rebuildTabs() {
        tabStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if projectNames.isEmpty {
            let label = NSTextField(labelWithString: "  ⚡ 等待 Kiro 窗口...  ")
            label.font = .systemFont(ofSize: 12)
            label.textColor = NSColor(white: 0.5, alpha: 1)
            tabStack.addArrangedSubview(label)
            return
        }
        
        for (i, name) in projectNames.enumerated() {
            let isActive = (name == activeProject)
            
            let container = NSView()
            container.wantsLayer = true
            container.translatesAutoresizingMaskIntoConstraints = false
            
            if isActive {
                container.layer?.backgroundColor = NSColor(white: 1, alpha: 0.12).cgColor
            }
            
            // Blue bottom indicator for active tab
            if isActive {
                let ind = NSView()
                ind.wantsLayer = true
                ind.layer?.backgroundColor = NSColor(red: 0.30, green: 0.56, blue: 1.0, alpha: 1).cgColor
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
            
            let btn = NSButton(title: "⚡ \(name)", target: self, action: #selector(tabClicked(_:)))
            btn.tag = i
            btn.isBordered = false
            btn.font = .systemFont(ofSize: 13, weight: isActive ? .bold : .medium)
            btn.contentTintColor = isActive ? .white : NSColor(white: 0.65, alpha: 1)
            btn.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(btn)
            
            NSLayoutConstraint.activate([
                container.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
                btn.topAnchor.constraint(equalTo: container.topAnchor),
                btn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                btn.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                btn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            ])
            
            tabStack.addArrangedSubview(container)
        }
    }
    
    @objc private func tabClicked(_ sender: NSButton) {
        let idx = sender.tag
        guard idx >= 0 && idx < projectNames.count else { return }
        let project = projectNames[idx]
        activeProject = project
        rebuildTabs()
        manager.activate(project: project)
    }
    
    // MARK: - Follow Kiro Window
    private func followKiroWindow() {
        // Only show when Kiro is frontmost
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              (frontApp.localizedName == "Kiro" || (frontApp.bundleIdentifier ?? "").contains("kiro")),
              frontApp.executableURL?.path.contains("Kiro.app") == true else {
            if isVisible { orderOut(nil) }
            return
        }
        
        if !isVisible { orderFront(nil) }
        
        guard let info = manager.getFocusedWindowFrame() else { return }
        let kiroFrame = info.frame  // CG coords (top-left origin)
        
        // Skip if Kiro window hasn't moved (no work needed)
        if kiroFrame == lastKiroFrame { return }
        lastKiroFrame = kiroFrame
        
        // Update active project highlight
        if info.project != activeProject {
            activeProject = info.project
            rebuildTabs()
        }
        
        // Position bar above the Kiro window
        let screenH = NSScreen.main?.frame.height ?? 900
        let barX = kiroFrame.origin.x
        let barY = screenH - kiroFrame.origin.y  // NS coords: bottom of bar = top of Kiro
        let barW = kiroFrame.width
        
        let newFrame = CGRect(x: barX, y: barY, width: barW, height: barHeight)
        setFrame(newFrame, display: false, animate: false)
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
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "⚡K"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示/隐藏", action: #selector(toggle), keyEquivalent: "k"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
        
        panel = TabBarPanel()
        panel?.orderFront(nil)
    }
    
    @objc func toggle() {
        if panel?.isVisible == true { panel?.orderOut(nil) }
        else { panel?.orderFront(nil) }
    }
    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
