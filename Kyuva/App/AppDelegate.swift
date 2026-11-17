import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
#if DEBUG
    override init() {
        _ = try! QAAutomationConfiguration.current()
        super.init()
    }
#endif
    
    private var statusItem: NSStatusItem?
    private var overlayWindowController: OverlayWindowController?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var shouldShowOverlayAfterOnboarding = false
#if DEBUG
    private var automationSocket: QAAutomationSocket?
#endif
    
    func applicationDidFinishLaunching(_ notification: Notification) {
#if DEBUG
        do {
            if let configuration = try QAAutomationConfiguration.current() {
                // This explicitly isolated QA mode never installs global hotkeys,
                // opens onboarding or takes the user's keyboard focus.
                overlayWindowController = OverlayWindowController(interactive: false)
                let socket = QAAutomationSocket(
                    configuration: configuration,
                    state: { [weak self] in self?.automationState() ?? [:] },
                    command: { [weak self] command in
                        guard let self else {
                            throw QAAutomationHTTPError(status: 503, message: "Application unavailable")
                        }
                        return try self.automationCommand(command)
                    }
                )
                try socket.start()
                automationSocket = socket
                return
            }
        } catch {
            // An invalid explicit QA configuration must not fall back to a real library.
            preconditionFailure("Refusing unsafe or unavailable QA automation configuration")
        }
#endif
        let completed = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        print("[Kyuva] Starting up, hasCompletedOnboarding: \(completed)")
        
        setupStatusBarItem()
        setupOverlayWindow(isVisible: false)
        
        // Listen for onboarding triggers from UI
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showOnboardingManual),
            name: .showOnboarding,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: .showSettings,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showOverlay),
            name: .showOverlay,
            object: nil
        )
        
        // Kyuva remains a menu-bar agent throughout onboarding; the welcome
        // window can become key without adding a temporary Dock icon.
        if !completed {
            print("[Kyuva] Showing onboarding...")
            showOnboarding(showOverlayOnClose: false)
        } else {
            print("[Kyuva] Skipping onboarding, already completed")
            openSettings()
        }
    }
    
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Kyuva")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Kyuva", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show Prompt", action: #selector(showOverlay), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "Hide Prompt", action: #selector(hideOverlay), keyEquivalent: "h"))
        let nextDisplayItem = NSMenuItem(
            title: "Move to Next Display",
            action: #selector(moveOverlayToNextDisplay),
            keyEquivalent: ""
        )
        menu.addItem(nextDisplayItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Welcome Guide…", action: #selector(showOnboardingManual), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Kyuva", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    private func setupOverlayWindow(isVisible: Bool) {
        overlayWindowController = OverlayWindowController()
        if isVisible {
            overlayWindowController?.showOverlay()
        } else {
            overlayWindowController?.hideOverlay()
        }
    }
    
    private func showOnboarding(showOverlayOnClose: Bool) {
        if let onboardingWindow {
            onboardingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        shouldShowOverlayAfterOnboarding = showOverlayOnClose
        
        let onboardingView = OnboardingHostView(
            onDismiss: { [weak self] in
                self?.onboardingWindow?.close()
            }
        )
        
        onboardingWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 670, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        onboardingWindow?.isReleasedWhenClosed = false
        onboardingWindow?.title = "Welcome to Kyuva"
        onboardingWindow?.contentView = NSHostingView(rootView: onboardingView)
        onboardingWindow?.delegate = self
        onboardingWindow?.center()
        // Make sure it appears above everything
        onboardingWindow?.level = .floating
        onboardingWindow?.makeKeyAndOrderFront(nil)
        onboardingWindow?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showOnboardingManual() {
        showOnboarding(
            showOverlayOnClose: overlayWindowController?.isOverlayVisible ?? false
        )
    }
    
    @objc private func showOverlay() {
        overlayWindowController?.showOverlay()
    }
    
    @objc private func hideOverlay() {
        overlayWindowController?.hideOverlay()
    }

    @objc func moveOverlayToNextDisplay() {
        overlayWindowController?.moveToNextDisplay()
    }
    
    @objc private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1080, height: 680),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.isReleasedWhenClosed = false
            settingsWindow?.title = "Kyuva"
            settingsWindow?.minSize = NSSize(width: 920, height: 580)
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
            settingsWindow?.delegate = self
            settingsWindow?.center()
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        switch ScriptManager.shared.flushPendingSave() {
        case .success:
#if DEBUG
            automationSocket?.stop()
#endif
            return .terminateNow
        case .failure:
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Your latest changes aren't saved."
            alert.informativeText = "Keep Kyuva open to retry saving or export your script. Quitting without saving discards your unsaved changes."
            alert.addButton(withTitle: "Keep Editing")
            let quitButton = alert.addButton(withTitle: "Quit Without Saving")
            quitButton.hasDestructiveAction = true
            return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
        }
    }

#if DEBUG
    private func automationState() -> [String: Any] {
        let manager = ScriptManager.shared
        let saveState: String
        switch manager.saveState {
        case .pending: saveState = "pending"
        case .saving: saveState = "saving"
        case .saved: saveState = "saved"
        case .failed: saveState = "failed"
        }
        let snapshot: [String: Any] = [
            "schema_version": 1,
            "bundle_id": Bundle.main.bundleIdentifier ?? "",
            "isolated_qa": true,
            "state_limited": false,
            "save_state": saveState,
            "load_error": manager.loadError != nil,
            "selected_script_id": manager.selectedScriptId?.uuidString as Any? ?? NSNull(),
            "scripts": manager.scripts.map { ["id": $0.id.uuidString, "name": $0.name, "text": $0.content] },
            "prompt": overlayWindowController?.automationState ?? [:]
        ]
        if let encoded = try? JSONSerialization.data(withJSONObject: snapshot), encoded.count <= 512 * 1024 {
            return snapshot
        }
        // Large QA libraries stay intact and commands still return bounded acknowledgments.
        return ["schema_version": 1, "isolated_qa": true, "state_limited": true,
                "script_count": manager.scripts.count, "save_state": saveState,
                "load_error": manager.loadError != nil]
    }

    private func automationCommand(_ request: [String: Any]) throws -> QAAutomationResponse {
        guard let command = request["command"] as? String else {
            throw QAAutomationHTTPError(status: 400, message: "A command is required")
        }
        let manager = ScriptManager.shared
        guard manager.loadError == nil else {
            throw QAAutomationHTTPError(status: 409, message: "Library could not be opened")
        }
        let allowed: Set<String>
        switch command {
        case "createScript": allowed = ["command", "name", "text"]
        case "selectScript": allowed = ["command", "id"]
        default: allowed = ["command"]
        }
        guard Set(request.keys) == allowed else {
            throw QAAutomationHTTPError(status: 400, message: "Unexpected or missing arguments")
        }
        switch command {
        case "createScript":
            guard let name = request["name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  name.utf8.count <= 512, let text = request["text"] as? String,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf8.count <= 60_000 else {
                throw QAAutomationHTTPError(status: 400, message: "Invalid script")
            }
            manager.createNewScript()
            guard let id = manager.selectedScriptId else {
                throw QAAutomationHTTPError(status: 500, message: "Script creation failed")
            }
            manager.updateScriptName(id, name: name)
            manager.updateScriptContent(id, content: text)
        case "selectScript":
            guard let raw = request["id"] as? String, let id = UUID(uuidString: raw),
                  manager.scripts.contains(where: { $0.id == id }) else {
                throw QAAutomationHTTPError(status: 404, message: "Script not found")
            }
            manager.selectedScriptId = id
        case "save", "quit":
            guard case .success = manager.flushPendingSave() else {
                throw QAAutomationHTTPError(status: 409, message: "Script was not saved")
            }
            if command == "quit" {
                return QAAutomationResponse(json: ["quitting": true], afterReply: {
                    NSApplication.shared.terminate(nil)
                })
            }
        case "showPrompt":
            overlayWindowController?.showOverlay(activate: false)
        case "hidePrompt":
            hideOverlay()
        case "start":
            guard overlayWindowController?.isOverlayVisible == true else {
                throw QAAutomationHTTPError(status: 409, message: "Open the prompt first")
            }
            overlayWindowController?.automationStart()
        case "pause":
            overlayWindowController?.automationPause()
        default:
            throw QAAutomationHTTPError(status: 400, message: "Unknown command")
        }
        return QAAutomationResponse(json: [
            "accepted": true, "command": command,
            "selected_script_id": manager.selectedScriptId?.uuidString as Any? ?? NSNull()
        ])
    }
#endif

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }

        if closingWindow === onboardingWindow {
            let shouldShowOverlay = shouldShowOverlayAfterOnboarding

            // Defer overlay restoration until AppKit finishes the close event.
            DispatchQueue.main.async { [weak self] in
                self?.onboardingWindow = nil
                if shouldShowOverlay {
                    self?.overlayWindowController?.showOverlay()
                } else {
                    self?.overlayWindowController?.hideOverlay()
                    self?.openSettings()
                }
            }
        } else if closingWindow === settingsWindow {
            DispatchQueue.main.async { [weak self] in
                self?.settingsWindow = nil
            }
        }
    }
}

// Helper view to handle onboarding dismissal
struct OnboardingHostView: View {
    var onDismiss: () -> Void
    @State private var isPresented = true
    
    var body: some View {
        OnboardingView(isPresented: $isPresented)
            .onChange(of: isPresented) { newValue in
                if !newValue {
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    onDismiss()
                }
            }
    }
}
