import Foundation

/// Local JSON storage for scripts and settings
class LocalStore {
    
    private let scriptsURL: URL
    private let backupURL: URL
    private let saveQueue: DispatchQueue
    // Accessed only on saveQueue, including synchronous result readback.
    private var lastSaveResult: Result<Void, Error> = .success(())
    
    enum QAStorageConfigurationError: LocalizedError {
        case absoluteDirectoryRequired

        var errorDescription: String? {
            "Kyuva QA requires an absolute KyuvaQAStorageDirectory Info.plist value. No default library was opened."
        }
    }

    /// QA app routing must survive launches that do not inherit the shell environment.
    static func qaStorageDirectory(bundleIdentifier: String?, fixturePath: String?) throws -> URL? {
        guard bundleIdentifier?.hasPrefix("com.kikuai.kyuva.qa") == true else { return nil }
        guard let fixturePath, fixturePath.hasPrefix("/"), !fixturePath.contains("\0") else {
            throw QAStorageConfigurationError.absoluteDirectoryRequired
        }
        return URL(fileURLWithPath: fixturePath, isDirectory: true).standardizedFileURL
    }

    init(
        directoryURL: URL? = nil,
        saveQueue: DispatchQueue? = nil
    ) {
        self.saveQueue = saveQueue ?? DispatchQueue(label: "com.kyuva.storage", qos: .background)

#if DEBUG
        let qaDirectory: URL?
        if directoryURL == nil {
            do {
                qaDirectory = try Self.qaStorageDirectory(
                    bundleIdentifier: Bundle.main.bundleIdentifier,
                    fixturePath: Bundle.main.object(forInfoDictionaryKey: "KyuvaQAStorageDirectory") as? String
                )
            } catch {
                // Fail before any FileManager call or Application Support fallback.
                preconditionFailure(error.localizedDescription)
            }
        } else {
            qaDirectory = nil
        }
        let debugDirectory = ProcessInfo.processInfo.environment["KYUVA_STORAGE_DIRECTORY"]
            .flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
#else
        let qaDirectory: URL? = nil
        let debugDirectory: URL? = nil
#endif

        let storageDirectory: URL
        if let directoryURL {
            storageDirectory = directoryURL
        } else if let qaDirectory {
            storageDirectory = qaDirectory
        } else if let debugDirectory {
            storageDirectory = debugDirectory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            storageDirectory = appSupport.appendingPathComponent("Kyuva", isDirectory: true)
        }
        
        scriptsURL = storageDirectory.appendingPathComponent("scripts.json")
        backupURL = storageDirectory.appendingPathComponent("scripts.backup.json")
    }
    
    // MARK: - Scripts
    
    enum LibraryError: LocalizedError {
        case cannotOpen
        case changedDuringRecovery

        var errorDescription: String? {
            switch self {
            case .cannotOpen:
                return "The script library couldn't be opened. Existing files were not replaced."
            case .changedDuringRecovery:
                return "The original script file could not be safely preserved. Existing files were not replaced."
            }
        }
    }

    func loadScripts() throws -> [Script] {
        try readLibrary().scripts
    }

    /// Read directly rather than synchronizing with the write queue: callers
    /// may inspect a library while an injected save queue is suspended.
    private func readLibrary() throws -> (scripts: [Script], primaryData: Data?) {
        try FileManager.default.createDirectory(
            at: scriptsURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        if let primary = try readIfPresent(at: scriptsURL) {
            if let scripts = try? decodeScripts(from: primary) {
                return (scripts, primary)
            }
            guard let backup = try readIfPresent(at: backupURL) else { throw LibraryError.cannotOpen }
            let recovered = try decodeScripts(from: backup)
            try preserveCorruptPrimary(expectedData: primary)
            return (recovered, nil)
        }
        if let backup = try readIfPresent(at: backupURL) {
            return (try decodeScripts(from: backup), nil)
        }
        return ([], nil) // Only a confirmed missing pair is a new library.
    }

    private func readIfPresent(at url: URL) throws -> Data? {
        do {
            return try Data(contentsOf: url)
        } catch {
            let failure = error as NSError
            guard failure.domain == NSCocoaErrorDomain,
                  failure.code == CocoaError.fileReadNoSuchFile.rawValue else { throw error }
            return nil
        }
    }

    func saveScripts(_ scripts: [Script], completion: ((Result<Void, Error>) -> Void)? = nil) {
        let scriptsCopy = scripts // Capture copy for thread safety
        saveQueue.async {
            let result = Result<Void, Error> {
                let data = try JSONEncoder().encode(scriptsCopy)
                // Revalidate at write time too. A failed current read must
                // never become permission to skip backup and replace the file.
                let library = try self.readLibrary()
                if let currentData = library.primaryData {
                    try currentData.write(to: self.backupURL, options: .atomic)
                }

                // Data's atomic option writes a complete replacement file, so a
                // crash cannot leave a partially encoded scripts document.
                try data.write(to: self.scriptsURL, options: .atomic)
            }
            self.lastSaveResult = result
            completion?(result)
        }
    }

    /// Wait for ordered writes and report the last actual disk result.
    @discardableResult
    func waitForPendingWrites() -> Result<Void, Error> {
        saveQueue.sync { lastSaveResult }
    }

    private func decodeScripts(from data: Data) throws -> [Script] {
        var scripts = try JSONDecoder().decode([Script].self, from: data)
        for index in scripts.indices {
            scripts[index].reindex()
        }
        return scripts
    }

    @discardableResult
    private func preserveCorruptPrimary(expectedData: Data) throws -> URL {
        let preservedURL = scriptsURL.deletingLastPathComponent().appendingPathComponent(
            "scripts.corrupt-\(UUID().uuidString).json"
        )
        try FileManager.default.copyItem(at: scriptsURL, to: preservedURL)
        guard try Data(contentsOf: preservedURL) == expectedData,
              try Data(contentsOf: scriptsURL) == expectedData else {
            throw LibraryError.changedDuringRecovery
        }
        return preservedURL
    }
}
