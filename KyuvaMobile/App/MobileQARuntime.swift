import Foundation

/// The mobile composition root. Selection precedes any production singleton.
@MainActor
final class MobileRuntime {
    /// Safe for WatchConnectivity delegate callbacks: no runtime, models,
    /// preferences, audio, or WCSession are initialized by this predicate.
    nonisolated static let isQARequested = requestsQA(
        environment: ProcessInfo.processInfo.environment
    )

    nonisolated private static func requestsQA(environment: [String: String]) -> Bool {
        #if DEBUG
        return environment["KYUVA_MOBILE_QA_ID"] != nil ||
            environment["XCTestConfigurationFilePath"] != nil ||
            environment["XCTestBundlePath"] != nil ||
            environment["XCTestSessionIdentifier"] != nil ||
            NSClassFromString("XCTestCase") != nil
        #else
        return false
        #endif
    }

    static let current: MobileRuntime = {
        do {
            return try make(environment: ProcessInfo.processInfo.environment)
        } catch {
            preconditionFailure("Invalid mobile QA configuration. No normal library was opened.")
        }
    }()

    let isQA: Bool
    let userDefaults: UserDefaults
    let scriptManager: ScriptManager
    let proStore: ProEntitlementStore
    let storageDirectory: URL?
    let preferencesDomain: String?
    var commerceEnabled: Bool { !isQA && ProEntitlementStore.commerceEnabled }
    var allowsVoiceFollow: Bool { !isQA }

    #if DEBUG
    /// Readback only: the installed QA view owns this controller's lifetime.
    private(set) weak var qaScrollController: ScrollController?
    #endif

    enum ConfigurationError: Error {
        case invalidIdentity
        case unsafeStorage
        case unavailablePreferences
    }

    static func make(environment: [String: String]) throws -> MobileRuntime {
        #if DEBUG
        if let value = environment["KYUVA_MOBILE_QA_ID"] {
            guard let id = UUID(uuidString: value), value.lowercased() == id.uuidString.lowercased() else {
                throw ConfigurationError.invalidIdentity
            }
            return try MobileRuntime(qaID: id)
        }
        if requestsQA(environment: environment) {
            return try MobileRuntime(qaID: UUID())
        }
        #endif
        return MobileRuntime()
    }

    private init() {
        isQA = false
        storageDirectory = nil
        preferencesDomain = nil
        userDefaults = .standard
        scriptManager = .shared
        proStore = .shared
    }

    #if DEBUG
    private init(qaID: UUID) throws {
        let identity = qaID.uuidString.lowercased()
        let domain = "com.kikuai.kyuva.mobile.qa.\(identity)"
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        ).resolvingSymlinksInPath()
        let directory = support.appendingPathComponent("KyuvaMobileQA", isDirectory: true)
            .appendingPathComponent(identity, isDirectory: true)
            .appendingPathComponent("scripts", isDirectory: true)
        try Self.validateStorage(directory)
        guard let defaults = MobileQADefaults(suiteName: domain) else {
            throw ConfigurationError.unavailablePreferences
        }
        isQA = true
        userDefaults = defaults
        storageDirectory = directory
        preferencesDomain = domain
        scriptManager = ScriptManager(storage: LocalStore(
            directoryURL: directory,
            validateAccess: { try Self.validateStorage(directory) }
        ))
        proStore = ProEntitlementStore(userDefaults: defaults, commerceEnabled: false)
    }

    /// Rechecked by LocalStore on its write queue as well as before every read.
    nonisolated private static func validateStorage(_ directory: URL) throws {
        let manager = FileManager.default
        var current = URL(fileURLWithPath: "/", isDirectory: true)
        for component in directory.pathComponents.dropFirst() {
            current.appendPathComponent(component, isDirectory: true)
            do {
                let attributes = try manager.attributesOfItem(atPath: current.path)
                guard attributes[.type] as? FileAttributeType == .typeDirectory else {
                    throw ConfigurationError.unsafeStorage
                }
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                // Missing components are created by the real LocalStore only.
            }
        }
        for name in ["scripts.json", "scripts.backup.json"] {
            let leaf = directory.appendingPathComponent(name)
            do {
                let attributes = try manager.attributesOfItem(atPath: leaf.path)
                guard attributes[.type] as? FileAttributeType == .typeRegular,
                      let referenceCount = attributes[.referenceCount] as? NSNumber,
                      referenceCount.intValue == 1 else {
                    throw ConfigurationError.unsafeStorage
                }
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                // A missing primary/backup pair is a new isolated library.
            }
        }
    }
    #endif

    func makeScrollController(startTimer: Bool = true) -> ScrollController {
        let controller = ScrollController(startTimer: startTimer, userDefaults: userDefaults)
        #if DEBUG
        if isQA { qaScrollController = controller }
        #endif
        return controller
    }

    func makeSpeechRecognizer() -> OnDeviceSpeechRecognizer {
        OnDeviceSpeechRecognizer(isEnabled: allowsVoiceFollow)
    }
}

#if DEBUG
/// A suite alone still searches global/argument/registration domains. QA reads
/// only its own persistent domain, including AppStorage's typed getter paths.
private final class MobileQADefaults: UserDefaults {
    private let domain: String

    override init?(suiteName: String?) {
        guard let suiteName else { return nil }
        domain = suiteName
        super.init(suiteName: suiteName)
    }

    override func object(forKey key: String) -> Any? { persistentDomain(forName: domain)?[key] }
    override func string(forKey key: String) -> String? { object(forKey: key) as? String }
    override func array(forKey key: String) -> [Any]? { object(forKey: key) as? [Any] }
    override func dictionary(forKey key: String) -> [String: Any]? { object(forKey: key) as? [String: Any] }
    override func data(forKey key: String) -> Data? { object(forKey: key) as? Data }
    override func stringArray(forKey key: String) -> [String]? { object(forKey: key) as? [String] }
    override func integer(forKey key: String) -> Int { number(forKey: key)?.intValue ?? 0 }
    override func float(forKey key: String) -> Float { number(forKey: key)?.floatValue ?? 0 }
    override func double(forKey key: String) -> Double { number(forKey: key)?.doubleValue ?? 0 }
    override func bool(forKey key: String) -> Bool { number(forKey: key)?.boolValue ?? false }
    override func url(forKey key: String) -> URL? {
        guard let value = string(forKey: key) else { return nil }
        return URL(string: value)
    }
    override func dictionaryRepresentation() -> [String: Any] { persistentDomain(forName: domain) ?? [:] }

    private func number(forKey key: String) -> NSNumber? {
        if let value = object(forKey: key) as? NSNumber { return value }
        if let value = object(forKey: key) as? NSString { return NSNumber(value: value.doubleValue) }
        return nil
    }
}
#endif
