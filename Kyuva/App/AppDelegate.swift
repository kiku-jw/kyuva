import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusItem: NSStatusItem?
    private var overlayWindowController: OverlayWindowController?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let completed = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        print("[Kyuva] Starting up, hasCompletedOnboarding: \(completed)")
        
        setupStatusBarItem()
        setupOverlayWindow()
        
        // Listen for onboarding triggers from UI
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showOnboardingManual),
            name: NSNotification.Name("ShowOnboarding"),
            object: nil
        )
        
        // Show onboarding on first launch (BEFORE hiding dock icon)
        if !completed {
            print("[Kyuva] Showing onboarding...")
            // Keep dock icon visible during onboarding
            NSApp.setActivationPolicy(.regular)
            showOnboarding()
        } else {
            print("[Kyuva] Skipping onboarding, already completed")
            // Hide dock icon (menu bar app) - only after onboarding completed
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Kyuva")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Teleprompter", action: #selector(showOverlay), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "Hide Teleprompter", action: #selector(hideOverlay), keyEquivalent: "h"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Welcome Tour...", action: #selector(showOnboardingManual), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Kyuva", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    private func setupOverlayWindow() {
        overlayWindowController = OverlayWindowController()
        overlayWindowController?.showWindow(nil)
    }
    
    private func showOnboarding() {
        // Create binding for onboarding state
        @State var isPresented = true
        
        let onboardingView = OnboardingHostView(
            onDismiss: { [weak self] in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
                // Hide dock icon after onboarding completes
                NSApp.setActivationPolicy(.accessory)
            }
        )
        
        onboardingWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 670, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        onboardingWindow?.title = "Welcome to Kyuva"
        onboardingWindow?.contentView = NSHostingView(rootView: onboardingView)
        onboardingWindow?.center()
        // Make sure it appears above everything
        onboardingWindow?.level = .floating
        onboardingWindow?.makeKeyAndOrderFront(nil)
        onboardingWindow?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showOnboardingManual() {
        showOnboarding()
    }
    
    @objc private func showOverlay() {
        overlayWindowController?.showWindow(nil)
    }
    
    @objc private func hideOverlay() {
        overlayWindowController?.close()
    }
    
    @objc private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "Kyuva Settings"
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
            settingsWindow?.center()
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
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
