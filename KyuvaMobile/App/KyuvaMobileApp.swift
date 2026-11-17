import SwiftUI

@main
struct KyuvaMobileApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var scriptManager: ScriptManager
    private let runtime: MobileRuntime

    init() {
        let runtime = MobileRuntime.current
        self.runtime = runtime
        _scriptManager = StateObject(wrappedValue: runtime.scriptManager)
        if !runtime.isQA { PhoneWatchSession.shared.activate() }
    }

    var body: some Scene {
        WindowGroup {
            MobileEditorView(runtime: runtime)
                .environmentObject(scriptManager)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active {
                        scriptManager.flushPendingSave()
                    }
                }
        }
    }
}
