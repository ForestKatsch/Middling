import Cocoa
import SwiftUI
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let eventTap = EventTap()
    private let setupModel = SetupModel()

    private var statusItem: NSStatusItem!
    private var enabledMenuItem: NSMenuItem!
    private var permissionsMenuItem: NSMenuItem!
    private var launchAtLoginMenuItem: NSMenuItem!
    private var setupWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var permissionPollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        terminateOtherInstances()
        setUpStatusItem()
        setUpSetupModel()

        if AXIsProcessTrusted() {
            if !eventTap.start() {
                if CommandLine.arguments.contains("--relaunched") {
                    // Already relaunched once and the tap is still refused;
                    // surface the setup window instead of looping.
                    showSetupWindow()
                } else {
                    relaunch()
                    return
                }
            }
        } else {
            // Do not attempt tap creation while untrusted: a failed attempt
            // spawns the system permission dialog on its own.
            startPermissionPolling()
            // AXIsProcessTrusted can report a stale false in the first
            // moments after launch; give the poll a beat before showing
            // the window so granted launches stay windowless.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, !self.eventTap.isRunning else { return }
                self.showSetupWindow()
            }
        }
        refreshUI()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication, hasVisibleWindows: Bool
    ) -> Bool {
        if !eventTap.isRunning {
            showSetupWindow()
            startPermissionPolling()
        }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventTap.stop()
    }

    private func menuBarIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "middling", withExtension: "svg"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            return image
        }
        return NSImage(
            systemSymbolName: "computermouse.fill",
            accessibilityDescription: "Middling"
        )
    }

    private func terminateOtherInstances() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let current = ProcessInfo.processInfo.processIdentifier
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        where app.processIdentifier != current {
            app.terminate()
        }
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = menuBarIcon()
        }

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        let aboutItem = NSMenuItem(
            title: "About Middling",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        enabledMenuItem = NSMenuItem(
            title: "Enabled",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledMenuItem.target = self
        menu.addItem(enabledMenuItem)

        permissionsMenuItem = NSMenuItem(
            title: "More Permissions Required…",
            action: #selector(openSetup),
            keyEquivalent: ""
        )
        permissionsMenuItem.target = self
        menu.addItem(permissionsMenuItem)

        menu.addItem(.separator())

        launchAtLoginMenuItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginMenuItem.target = self
        menu.addItem(launchAtLoginMenuItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Middling",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func refreshUI() {
        let running = eventTap.isRunning
        enabledMenuItem.state = eventTap.isEnabled ? .on : .off
        enabledMenuItem.isEnabled = running
        permissionsMenuItem.isHidden = running

        let launchAtLogin = SMAppService.mainApp.status == .enabled
        launchAtLoginMenuItem.state = launchAtLogin ? .on : .off

        setupModel.trusted = running
        setupModel.launchAtLogin = launchAtLogin

        if let button = statusItem.button {
            button.appearsDisabled = !(running && eventTap.isEnabled)
        }
    }

    // MARK: - Setup window

    private func setUpSetupModel() {
        setupModel.onOpenSettings = { [weak self] in
            self?.requestAccessibilityAccess()
        }
        setupModel.onToggleLaunchAtLogin = { [weak self] enable in
            self?.setLaunchAtLogin(enable)
        }
        setupModel.onDone = { [weak self] in
            self?.setupWindow?.close()
        }
    }

    private func showSetupWindow() {
        if setupWindow == nil {
            let hosting = NSHostingController(rootView: SetupView(model: setupModel))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Middling"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.center()
            setupWindow = window
        }
        setupWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Accessibility permission

    private func requestAccessibilityAccess() {
        // Registers Middling in the Accessibility list. The system dialog
        // only appears while the app is unregistered, so this is one-time.
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!
        NSWorkspace.shared.open(url)
        startPermissionPolling()
    }

    private func startPermissionPolling() {
        guard permissionPollTimer == nil else { return }
        permissionPollTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0, repeats: true
        ) { [weak self] timer in
            guard let self, AXIsProcessTrusted() else { return }
            timer.invalidate()
            self.permissionPollTimer = nil
            if self.eventTap.start() {
                self.refreshUI()
                self.setupWindow?.close()
            } else {
                // Trusted, but tap creation is still refused in this
                // process: relaunch to pick up the grant cleanly.
                self.relaunch()
            }
        }
    }

    private func relaunch() {
        let url = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = ["--relaunched"]
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    // MARK: - Actions

    @objc private func showAbout() {
        if aboutWindow == nil {
            let hosting = NSHostingController(rootView: AboutView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "About Middling"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.center()
            aboutWindow = window
        }
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleEnabled() {
        eventTap.isEnabled.toggle()
        refreshUI()
    }

    @objc private func openSetup() {
        showSetupWindow()
        startPermissionPolling()
    }

    @objc private func toggleLaunchAtLogin() {
        setLaunchAtLogin(SMAppService.mainApp.status != .enabled)
    }

    private func setLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Launch at login toggle failed: \(error)")
        }
        refreshUI()
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        refreshUI()
    }
}
