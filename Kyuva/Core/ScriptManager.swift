import Foundation
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif
import Combine

/// Manages scripts: CRUD, tokenization, import/export
class ScriptManager: ObservableObject {
    
    static let shared = ScriptManager()

    enum SaveState: Equatable {
        case pending
        case saving
        case saved
        case failed(String)
    }

    @Published private(set) var saveState: SaveState = .saved
    @Published private(set) var loadError: String?

    private struct OpeningFailure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    private var saveRevision: UInt64 = 0
    
    @Published var scripts: [Script] = []
    @Published var selectedScriptId: UUID?
    
    var selectedScript: Script? {
        scripts.first { $0.id == selectedScriptId }
    }
    
    /// Lines from the currently selected script
    var lines: [String] {
        selectedScript?.lines ?? []
    }

    var promptLines: [PromptLine] {
        selectedScript?.promptLines ?? []
    }
    
    /// Tokenized words for voice-sync matching
    var tokens: [Token] {
        selectedScript?.tokens ?? []
    }
    
    private let storage: LocalStore
    
    init(storage: LocalStore = LocalStore()) {
        self.storage = storage
        loadScripts()
        guard loadError == nil else { return }

        // Select first script by default
        if selectedScriptId == nil, let first = scripts.first {
            selectedScriptId = first.id
        }
        
        // Create default script if none exist
        if scripts.isEmpty {
            createNewScript()
        }
    }
    
    // MARK: - CRUD
    
    func createNewScript() {
        let script = Script(
            name: "New Script",
            content: defaultScriptContent
        )
        scripts.append(script)
        selectedScriptId = script.id
        saveScripts()
    }
    
    func deleteScripts(at indexSet: IndexSet) {
        for index in indexSet.sorted(by: >) where scripts.indices.contains(index) {
            scripts.remove(at: index)
        }
        if !scripts.contains(where: { $0.id == selectedScriptId }) {
            selectedScriptId = scripts.first?.id
        }
        saveScripts()
    }
    
    func updateScriptName(_ id: UUID, name: String) {
        guard let index = scripts.firstIndex(where: { $0.id == id }) else { return }
        scripts[index].name = name
        debouncedSave()
    }
    
    /// Update content immediately (for live preview) but debounce file save
    func updateScriptContent(_ id: UUID, content: String) {
        guard let index = scripts.firstIndex(where: { $0.id == id }) else { return }
        scripts[index].content = content
        // Reindex is cheap, do it immediately for live preview
        scripts[index].reindex()
        // Debounce the expensive disk save
        debouncedSave()
    }
    
    /// Trigger reindex for a script (immediate)
    func reindexScript(_ id: UUID) {
        guard let index = scripts.firstIndex(where: { $0.id == id }) else { return }
        scripts[index].reindex()
    }
    
    private var saveWorkItem: DispatchWorkItem?
    
    /// Call from UI to trigger debounced save
    func debounceSaveFromUI() {
        saveRevision += 1
        saveWorkItem?.cancel()
        guard let error = loadError else {
            scheduleDebouncedSave()
            return
        }
        saveWorkItem = nil
        saveState = .failed(error)
    }

    private func scheduleDebouncedSave() {
        saveState = .pending
        let workItem = DispatchWorkItem { [weak self] in
            self?.saveWorkItem = nil
            self?.saveScripts()
        }
        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
    
    private func debouncedSave() {
        debounceSaveFromUI()
    }

    /// Persist the latest in-memory scripts before the process exits.
    @discardableResult
    func flushPendingSave() -> Result<Void, Error> {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        if let error = loadError {
            saveRevision += 1
            saveState = .failed(error)
            return .failure(OpeningFailure(message: error))
        }
        saveScripts()
        let result = storage.waitForPendingWrites()
        applySaveResult(result, revision: saveRevision)
        return result
    }

    func retrySave() {
        if loadError != nil {
            retryOpening()
            return
        }
        saveWorkItem?.cancel()
        saveWorkItem = nil
        saveScripts()
    }
    
    func selectNextScript() {
        guard let currentId = selectedScriptId,
              let currentIndex = scripts.firstIndex(where: { $0.id == currentId }) else { return }
        
        let nextIndex = (currentIndex + 1) % scripts.count
        selectedScriptId = scripts[nextIndex].id
    }
    
    /// Revalidate disk without discarding any retained in-memory drafts.
    func retryOpening() {
        guard loadError != nil else { return }
        saveWorkItem?.cancel()
        saveWorkItem = nil
        saveRevision += 1
        do {
            let loaded = try storage.loadScripts()
            let drafts = scripts
            loadError = nil
            if drafts.isEmpty {
                scripts = loaded
                selectedScriptId = scripts.first?.id
                saveState = .saved
                if scripts.isEmpty { createNewScript() }
            } else {
                let draftIDs = Set(drafts.map(\.id))
                scripts = loaded.filter { !draftIDs.contains($0.id) } + drafts
                if !scripts.contains(where: { $0.id == selectedScriptId }) {
                    selectedScriptId = scripts.first?.id
                }
                // A successful read does not save drafts. Resume validated
                // autosave and keep the pending state until its write succeeds.
                debounceSaveFromUI()
            }
        } catch {
            recordOpeningFailure(error)
        }
    }

    // MARK: - Import/Export

    @discardableResult
    func importScript(name: String, content: String) -> Script {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let script = Script(
            name: trimmedName.isEmpty ? "Imported Script" : trimmedName,
            content: content
        )
        scripts.append(script)
        selectedScriptId = script.id
        saveScripts()
        return script
    }

    @discardableResult
    func importScript(from url: URL) throws -> Script {
        let content = try ScriptTextFile.readImport(from: url)
        return importScript(name: url.deletingPathExtension().lastPathComponent, content: content)
    }

#if os(macOS)
    func importScript() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try importScript(from: url)
            } catch {
                NSApp.presentError(error)
            }
        }
    }
#endif
    
#if os(macOS)
    func exportScript(_ script: Script) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(script.name).txt"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try script.content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                NSApp.presentError(error)
            }
        }
    }
#endif
    
    // MARK: - Persistence
    
    private func loadScripts() {
        do {
            scripts = try storage.loadScripts()
        } catch {
            recordOpeningFailure(error)
        }
    }

    private func recordOpeningFailure(_ error: Error) {
        let message = "Couldn't open your scripts. Check folder access and try again. " + error.localizedDescription
        loadError = message
        saveState = .failed(message)
    }
    
    private func saveScripts() {
        saveRevision += 1
        let revision = saveRevision
        if let error = loadError {
            saveState = .failed(error)
            return
        }
        saveState = .saving
        storage.saveScripts(scripts) { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                self?.applySaveResult(result, revision: revision)
            }
        }
    }

    private func applySaveResult(_ result: Result<Void, Error>, revision: UInt64) {
        // An older queued write cannot label a newer edit as saved or failed.
        guard revision == saveRevision else { return }
        switch result {
        case .success: saveState = .saved
        case .failure(let error): saveState = .failed(error.localizedDescription)
        }
    }
    
    // MARK: - Default Content
    
    private var defaultScriptContent: String {
#if os(iOS)
        """
        Welcome to Kyuva 👋

        Paste or write your script here,
        then tap Present to start prompting.

        • Tap the prompt to pause or resume
        • Use the large controls to change pace
        • Turn the phone sideways for a wider reading line

        Keep phrases short.
        One thought per line reads best.

        Your script stays on this iPhone.
        """
#else
        """
        Welcome to Kyuva 👋
        
        This text sits right next to your camera,
        so you can read notes while keeping natural eye contact.
        
        • Hover over the overlay to pause
        • Use Control + Option + ← / → to adjust speed
        • Press Control + Option + Space to pause/resume
        
        Replace this with your script, meeting notes,
        or bullet points.
        
        Quick tip: Keep phrases short.
        One thought per line reads best.
        
        You're ready to sound confident
        and look like you're not reading. ✨
        """
#endif
    }
}
