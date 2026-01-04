import Foundation

/// Local JSON storage for scripts and settings
class LocalStore {
    
    private let scriptsURL: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let kyuvaDir = appSupport.appendingPathComponent("Kyuva", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: kyuvaDir, withIntermediateDirectories: true)
        
        scriptsURL = kyuvaDir.appendingPathComponent("scripts.json")
    }
    
    // MARK: - Scripts
    
    func loadScripts() -> [Script] {
        guard FileManager.default.fileExists(atPath: scriptsURL.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: scriptsURL)
            var scripts = try JSONDecoder().decode([Script].self, from: data)
            
            // Reindex tokens (not persisted)
            for i in scripts.indices {
                scripts[i].reindex()
            }
            
            return scripts
        } catch {
            print("Failed to load scripts: \(error)")
            return []
        }
    }
    
    private let saveQueue = DispatchQueue(label: "com.kyuva.storage", qos: .background)
    
    func saveScripts(_ scripts: [Script]) {
        let scriptsCopy = scripts // Capture copy for thread safety
        saveQueue.async {
            do {
                let data = try JSONEncoder().encode(scriptsCopy)
                try data.write(to: self.scriptsURL)
            } catch {
                print("Failed to save scripts: \(error)")
            }
        }
    }
}
