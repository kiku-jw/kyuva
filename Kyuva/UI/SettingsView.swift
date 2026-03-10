import SwiftUI

struct SettingsView: View {
    @AppStorage("overlayOpacity") private var opacity: Double = 0.85
    @AppStorage("fontSize") private var fontSize: Double = 18
    @AppStorage("scrollSpeed") private var scrollSpeed: Double = 50
    @AppStorage("scrollMode") private var scrollMode: ScrollMode = .auto
    @AppStorage("useVoiceControl") private var voiceModeEnabled: Bool = false
    
    // Appearance
    @AppStorage("overlayWidth") private var overlayWidth: Double = 350
    @AppStorage("overlayHeight") private var overlayHeight: Double = 150
    @AppStorage("textAlignment") private var textAlignment: Int = 1 // 0=Left, 1=Center, 2=Right
    @AppStorage("fontFamily") private var fontFamily: Int = 0 // 0=System, 1=Mono, 2=Serif, 3=Rounded
    
    // Focus Mode
    @AppStorage("focusModeIntensity") private var focusModeIntensity: Int = 0 // 0=Off, 1=Subtle, 2=Medium, 3=Strong
    
    // Behavior
    @AppStorage("endBehavior") private var endBehavior: Int = 0 // 0=Do Nothing, 1=Start Over, 2=Loop
    
    @StateObject private var scriptManager = ScriptManager.shared
    @StateObject private var store = StoreManager.shared
    @StateObject private var audioMonitor = AudioLevelMonitor()
    
    @State private var showProUpgrade = false
    
    var body: some View {
        TabView {
            // Script Tab
            scriptTab
                .tabItem {
                    Label("Script", systemImage: "doc.text")
                }
            
            // Appearance Tab
            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
            
            // Scroll Tab
            scrollTab
                .tabItem {
                    Label("Scroll", systemImage: "scroll")
                }
            
            // Hotkeys Tab
            hotkeysTab
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }
            
            // About Tab
            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
            
            // Pro Tab
            proTab
                .tabItem {
                    Label(store.isPro ? "Pro ✓" : "Pro", systemImage: "star.fill")
                }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        .sheet(isPresented: $showProUpgrade) {
            ProUpgradeView()
        }
    }
    
    // MARK: - Script Tab
    
    @State private var showDeleteConfirm = false
    @State private var scriptToDelete: UUID?
    
    private var scriptTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with actions
            HStack {
                Text("Scripts")
                    .font(.headline)
                Spacer()
                
                if scriptManager.selectedScriptId != nil {
                    Button(action: {
                        scriptToDelete = scriptManager.selectedScriptId
                        showDeleteConfirm = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete selected script")
                }
                
                Button(action: { scriptManager.createNewScript() }) {
                    Image(systemName: "plus")
                }
                .help("New script")
                
                Button(action: { scriptManager.importScript() }) {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Import from file")
                
                if let script = scriptManager.selectedScript {
                    Button(action: { scriptManager.exportScript(script) }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("Export to file")
                }
            }
            
            // Script list
            List(selection: $scriptManager.selectedScriptId) {
                ForEach(scriptManager.scripts) { script in
                    HStack {
                        Text(script.name)
                        Spacer()
                        Text("\(script.content.split(separator: " ").count) words")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(script.id)
                    .contextMenu {
                        Button("Export") { scriptManager.exportScript(script) }
                        Divider()
                        Button("Delete", role: .destructive) {
                            scriptToDelete = script.id
                            showDeleteConfirm = true
                        }
                    }
                }
            }
            .frame(height: 120)
            .cornerRadius(6)
            
            // Script editor
            if let selectedId = scriptManager.selectedScriptId,
               let index = scriptManager.scripts.firstIndex(where: { $0.id == selectedId }) {
                
                // Name field
                TextField("Script Name", text: $scriptManager.scripts[index].name)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: scriptManager.scripts[index].name) { _ in
                        scriptManager.debounceSaveFromUI()
                    }
                
                // Stats bar
                HStack(spacing: 16) {
                    let wordCount = scriptManager.scripts[index].content.split(separator: " ").count
                    let readingTime = max(1, wordCount / 150)
                    
                    Label("\(wordCount) words", systemImage: "text.word.spacing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("~\(readingTime) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                // Content editor - direct binding, live updates
                TextEditor(text: $scriptManager.scripts[index].content)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(minHeight: 120)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .onChange(of: scriptManager.scripts[index].content) { _ in
                        scriptManager.reindexScript(selectedId)
                        scriptManager.debounceSaveFromUI()
                    }
            } else {
                Text("Select or create a script")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .alert("Delete Script?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let id = scriptToDelete,
                   let index = scriptManager.scripts.firstIndex(where: { $0.id == id }) {
                    scriptManager.deleteScripts(at: IndexSet(integer: index))
                }
                scriptToDelete = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    // MARK: - Appearance Tab
    
    private var appearanceTab: some View {
        Form {
            Section("Overlay Size") {
                HStack {
                    Text("Width")
                    Slider(value: $overlayWidth, in: 200...600, step: 10)
                    Text("\(Int(overlayWidth))px")
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                }
                
                HStack {
                    Text("Height")
                    Slider(value: $overlayHeight, in: 80...400, step: 10)
                    Text("\(Int(overlayHeight))px")
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                }
                
                HStack {
                    Text("Opacity")
                    Slider(value: $opacity, in: 0.3...1.0)
                    Text("\(Int(opacity * 100))%")
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                }
            }
            
            Section("Text") {
                Picker("Font", selection: $fontFamily) {
                    Text("System").tag(0)
                    Text("Monospaced").tag(1)
                    Text("Serif").tag(2)
                    Text("Rounded").tag(3)
                }
                
                HStack {
                    Text("Font Size")
                    Slider(value: $fontSize, in: 12...36)
                    Text("\(Int(fontSize)) pt")
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                }
                
                Picker("Text Alignment", selection: $textAlignment) {
                    Text("Left").tag(0)
                    Text("Center").tag(1)
                    Text("Right").tag(2)
                }
                .pickerStyle(.segmented)
            }
            
            Section("Focus Mode") {
                Text("Create a focused reading experience by dimming text outside the reading zone")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Intensity", selection: $focusModeIntensity) {
                    Text("Off").tag(0)
                    Text("Subtle").tag(1)
                    Text("Medium").tag(2)
                    Text("Strong").tag(3)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
    }
    
    // MARK: - Scroll Tab
    
    private var scrollTab: some View {
        Form {
            Section("Mode") {
                Picker("Scroll Mode", selection: $scrollMode) {
                    Text("Auto Scroll").tag(ScrollMode.auto)
                    Text("Manual").tag(ScrollMode.manual)
                    Text("Voice Follow").tag(ScrollMode.voiceFollow)
                }
                .pickerStyle(.segmented)
            }
            
            if scrollMode == .auto {
                Section("Speed") {
                    Slider(value: $scrollSpeed, in: 10...200) {
                        Text("Scroll Speed")
                    }
                    Text("\(Int(scrollSpeed)) px/sec")
                        .foregroundColor(.secondary)
                }
            }
            
            if scrollMode == .voiceFollow {
                Section("Voice Activation") {
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.orange)
                        Text("Voice-activated scrolling")
                    }
                    
                    if audioMonitor.permissionGranted {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Microphone access granted")
                                .foregroundColor(.secondary)
                        }
                        
                        // Audio level indicator
                        if audioMonitor.isMonitoring {
                            HStack {
                                Text("Level:")
                                ProgressView(value: Double(audioMonitor.audioLevel), total: 1.0)
                                Text(audioMonitor.isSpeaking ? "🎤 Speaking" : "🔇 Silent")
                                    .font(.caption)
                            }
                        }
                        
                        Toggle("Enable Voice Activation", isOn: $voiceModeEnabled)
                            .onChange(of: voiceModeEnabled) { enabled in
                                if enabled {
                                    audioMonitor.start()
                                } else {
                                    audioMonitor.stop()
                                }
                            }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            Text("Microphone access required")
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Request Microphone Access") {
                            audioMonitor.requestPermission { granted in
                                // Refresh UI
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)
                        Text("Audio is only used to detect speaking — nothing is recorded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            
            Section("Behavior") {
                Toggle("Pause on hover", isOn: .constant(true))
                Toggle("Smooth scrolling", isOn: .constant(true))
                
                Picker("When Scrolled to End", selection: $endBehavior) {
                    Text("Do Nothing").tag(0)
                    Text("Start Over").tag(1)
                    Text("Play Next Script").tag(2)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Hotkeys Tab
    
    private var hotkeysTab: some View {
        Form {
            Section("Global Shortcuts") {
                Text("Click a shortcut to record a new key combination")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HotkeyRow(label: "Speed Up", hotkeyKey: "hotkey_speedUp", defaultShortcut: "⇧ →")
                HotkeyRow(label: "Speed Down", hotkeyKey: "hotkey_speedDown", defaultShortcut: "⇧ ←")
                HotkeyRow(label: "Pause/Resume", hotkeyKey: "hotkey_togglePause", defaultShortcut: "⌃ Space")
                HotkeyRow(label: "Reset", hotkeyKey: "hotkey_reset", defaultShortcut: "⌘ R")
                HotkeyRow(label: "Toggle Overlay", hotkeyKey: "hotkey_toggleOverlay", defaultShortcut: "⌘ ⌥ T")
            }
            
            Section {
                Text("Note: Hotkey changes take effect after restarting the app")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
    }
    
    // MARK: - About Tab
    
    private var aboutTab: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // App icon and name
            VStack(spacing: 8) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
                
                Text("Kyuva")
                    .font(.largeTitle.bold())
                
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Your invisible teleprompter")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: {
                    if let url = URL(string: "mailto:support@kikuai.dev") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text("Send Feedback")
                    }
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    if let url = URL(string: "https://kikuai.dev/kyuva") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Website")
                    }
                }
                .buttonStyle(.bordered)
            }
            
            Button(action: {
                // Trigger Welcome Tour
                NotificationCenter.default.post(name: .init("ShowOnboarding"), object: nil)
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Show Welcome Guide")
                }
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
            
            Text("© 2025 KikuAI. All rights reserved.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - Pro Tab
    
    private var proTab: some View {
        VStack(spacing: 20) {
            if store.isPro {
                // Pro activated
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("Pro Activated")
                        .font(.title2.bold())
                    Text("Thank you for your support!")
                        .foregroundColor(.secondary)
                }
            } else {
                // Free user
                VStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.yellow)
                    Text("Upgrade to Pro")
                        .font(.title2.bold())
                    Text("Unlock all features")
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    ProFeatureRow(text: "Voice-Follow Scrolling", locked: true)
                    ProFeatureRow(text: "Unlimited Scripts (Free: 3)", locked: true)
                    ProFeatureRow(text: "Custom Hotkeys", locked: true)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                Button("Upgrade to Pro") {
                    showProUpgrade = true
                }
                .buttonStyle(.borderedProminent)
            }
            
            Spacer()
            
            Button("Restore Purchases") {
                Task {
                    await store.restorePurchases()
                }
            }
            .font(.caption)
        }
        .padding()
    }
}

struct ProFeatureRow: View {
    let text: String
    let locked: Bool
    
    var body: some View {
        HStack {
            Image(systemName: locked ? "lock.fill" : "checkmark")
                .foregroundColor(locked ? .orange : .green)
            Text(text)
            Spacer()
        }
    }
}

struct HotkeyRow: View {
    let label: String
    let hotkeyKey: String // UserDefaults key
    let defaultShortcut: String
    
    @State private var isRecording = false
    @State private var currentShortcut: String
    @State private var eventMonitor: Any?
    
    init(label: String, hotkeyKey: String, defaultShortcut: String) {
        self.label = label
        self.hotkeyKey = hotkeyKey
        self.defaultShortcut = defaultShortcut
        _currentShortcut = State(initialValue: UserDefaults.standard.string(forKey: hotkeyKey) ?? defaultShortcut)
    }
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            
            Button(action: { startRecording() }) {
                Text(isRecording ? "Press keys..." : currentShortcut)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isRecording ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.2))
                    .cornerRadius(4)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(isRecording ? .accentColor : .primary)
            }
            .buttonStyle(.plain)
            
            if currentShortcut != defaultShortcut {
                Button(action: { resetToDefault() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset to default")
            }
        }
    }
    
    private func startRecording() {
        isRecording = true
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let shortcut = formatShortcut(event)
            currentShortcut = shortcut
            UserDefaults.standard.set(shortcut, forKey: hotkeyKey)
            stopRecording()
            return nil // Consume the event
        }
    }
    
    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        isRecording = false
    }
    
    private func resetToDefault() {
        currentShortcut = defaultShortcut
        UserDefaults.standard.removeObject(forKey: hotkeyKey)
    }
    
    private func formatShortcut(_ event: NSEvent) -> String {
        var parts: [String] = []
        
        if event.modifierFlags.contains(.command) { parts.append("⌘") }
        if event.modifierFlags.contains(.option) { parts.append("⌥") }
        if event.modifierFlags.contains(.control) { parts.append("⌃") }
        if event.modifierFlags.contains(.shift) { parts.append("⇧") }
        
        // Map key codes to readable names
        let keyName: String
        switch event.keyCode {
        case 123: keyName = "←"
        case 124: keyName = "→"
        case 125: keyName = "↓"
        case 126: keyName = "↑"
        case 49: keyName = "Space"
        case 36: keyName = "↩"
        case 53: keyName = "Esc"
        case 51: keyName = "⌫"
        default:
            keyName = event.charactersIgnoringModifiers?.uppercased() ?? "?"
        }
        
        parts.append(keyName)
        return parts.joined(separator: " ")
    }
}

enum ScrollMode: String, CaseIterable {
    case auto
    case manual
    case voiceFollow
}
