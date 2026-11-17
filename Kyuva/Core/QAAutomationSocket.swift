#if DEBUG
import Foundation
import Darwin

struct QAAutomationHTTPError: Error {
    let status: Int
    let message: String
}

struct QAAutomationResponse {
    let json: [String: Any]
    let afterReply: (() -> Void)?

    init(json: [String: Any], afterReply: (() -> Void)? = nil) {
        self.json = json
        self.afterReply = afterReply
    }
}

struct QAAutomationConfiguration {
    let storageURL: URL
    let socketURL: URL
    private let bundleIdentifier: String
    private let homeDirectory: String

    static func current() throws -> Self? {
        let home = NSHomeDirectory()
        let configuration = try resolve(
            bundleIdentifier: Bundle.main.bundleIdentifier,
            enabled: Bundle.main.object(forInfoDictionaryKey: "KyuvaAutomationEnabled") as? Bool == true,
            storagePath: Bundle.main.object(forInfoDictionaryKey: "KyuvaQAStorageDirectory") as? String,
            homeDirectory: home
        )
        if configuration != nil, let fixedHome = ProcessInfo.processInfo.environment["CFFIXED_USER_HOME"] {
            guard fixedHome.hasPrefix("/"), URL(fileURLWithPath: fixedHome).standardizedFileURL.path == home else {
                throw QAAutomationHTTPError(status: 400, message: "Foreign QA preference home")
            }
        }
        return configuration
    }

    static func resolve(bundleIdentifier: String?, enabled: Bool, storagePath: String?,
                        homeDirectory: String) throws -> Self? {
        guard enabled else { return nil }
        func reject() -> QAAutomationHTTPError {
            QAAutomationHTTPError(status: 400, message: "Unsafe QA automation configuration")
        }
        guard let bundleIdentifier,
              bundleIdentifier.hasPrefix("com.kikuai.kyuva.qa.api."),
              bundleIdentifier.count > "com.kikuai.kyuva.qa.api.".count,
              bundleIdentifier.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 46 }),
              !bundleIdentifier.contains(".."), !bundleIdentifier.hasSuffix("."),
              validPath(homeDirectory),
              homeDirectory.hasSuffix("/Library/Containers/\(bundleIdentifier)/Data"),
              let storagePath, validPath(storagePath),
              storagePath == homeDirectory + "/tmp/KyuvaAutomation/scripts" else { throw reject() }
        let socketPath = homeDirectory + "/tmp/ka/a.sock"
        guard socketPath.utf8.count < MemoryLayout.size(ofValue: sockaddr_un().sun_path) else { throw reject() }
        try rejectSymlinks(in: storagePath)
        try rejectSymlinks(in: storagePath + "/scripts.json")
        try rejectSymlinks(in: storagePath + "/scripts.backup.json")
        try rejectSymlinks(in: socketPath)
        return Self(storageURL: URL(fileURLWithPath: storagePath),
                    socketURL: URL(fileURLWithPath: socketPath),
                    bundleIdentifier: bundleIdentifier, homeDirectory: homeDirectory)
    }

    private static func validPath(_ path: String) -> Bool {
        path.hasPrefix("/") && !path.utf8.contains(0)
            && URL(fileURLWithPath: path).standardizedFileURL.path == path
    }

    // lstat each existing component; never resolve a symlink into another library.
    private static func rejectSymlinks(in path: String) throws {
        var componentPath = ""
        for component in path.split(separator: "/") {
            componentPath += "/" + component
            var info = stat()
            if lstat(componentPath, &info) == 0 {
                guard (info.st_mode & S_IFMT) != S_IFLNK else {
                    throw QAAutomationHTTPError(status: 400, message: "Symlink in QA path")
                }
            } else if errno == ENOENT { return }
            else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        }
    }

    fileprivate func revalidate() throws {
        _ = try Self.resolve(bundleIdentifier: bundleIdentifier, enabled: true,
                             storagePath: storageURL.path, homeDirectory: homeDirectory)
    }
}

// One request per connection. All socket work runs on this private serial queue;
// UI closures run on main. stop never waits for a client or for main.
final class QAAutomationSocket {
    private let configuration: QAAutomationConfiguration
    private let state: () -> [String: Any]
    private let command: ([String: Any]) throws -> QAAutomationResponse
    private let queue = DispatchQueue(label: "com.kikuai.kyuva.qa.socket")
    private let lock = NSLock()
    private var source: DispatchSourceRead?
    private var socketIdentity: stat?
    private var started = false
    private var stopped = false

    init(configuration: QAAutomationConfiguration, state: @escaping () -> [String: Any],
         command: @escaping ([String: Any]) throws -> QAAutomationResponse) {
        self.configuration = configuration
        self.state = state
        self.command = command
    }

    func start() throws {
        lock.lock()
        defer { lock.unlock() }
        guard !started, !stopped else { throw QAAutomationHTTPError(status: 409, message: "Already started or stopped") }
        try configuration.revalidate()
        let parent = configuration.socketURL.deletingLastPathComponent().path
        let tmp = configuration.socketURL.deletingLastPathComponent().deletingLastPathComponent().path
        var tmpInfo = stat()
        guard lstat(tmp, &tmpInfo) == 0, (tmpInfo.st_mode & S_IFMT) == S_IFDIR,
              tmpInfo.st_uid == geteuid(), (tmpInfo.st_mode & 0o022) == 0 else {
            throw QAAutomationHTTPError(status: 400, message: "Unsafe QA temporary directory")
        }
        if mkdir(parent, 0o700) != 0 && errno != EEXIST { throw Self.posixError() }
        var parentInfo = stat()
        guard lstat(parent, &parentInfo) == 0, (parentInfo.st_mode & S_IFMT) == S_IFDIR,
              parentInfo.st_uid == geteuid(), (parentInfo.st_mode & 0o777) == 0o700 else {
            throw QAAutomationHTTPError(status: 400, message: "Unsafe QA socket directory")
        }
        let path = configuration.socketURL.path
        var prior = stat()
        guard lstat(path, &prior) != 0, errno == ENOENT else {
            throw QAAutomationHTTPError(status: 409, message: "QA socket path already exists")
        }
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw Self.posixError() }
        var bound = false
        var owned: stat?
        defer {
            if !bound {
                Darwin.close(descriptor)
                if let owned { Self.removeOwnedSocket(path: path, identity: owned) }
            }
        }
        _ = fcntl(descriptor, F_SETFD, FD_CLOEXEC)
        guard fcntl(descriptor, F_SETFL, O_NONBLOCK) == 0 else { throw Self.posixError() }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: Array(path.utf8) + [0])
        }
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else { throw Self.posixError() }
        var identity = stat()
        guard lstat(path, &identity) == 0 else { throw Self.posixError() }
        owned = identity
        guard chmod(path, 0o600) == 0, listen(descriptor, 4) == 0 else { throw Self.posixError() }
        let readSource = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        readSource.setEventHandler { [weak self] in self?.acceptOne(descriptor) }
        readSource.setCancelHandler {
            Darwin.close(descriptor)
            Self.removeOwnedSocket(path: path, identity: identity)
        }
        source = readSource
        socketIdentity = identity
        started = true
        bound = true
        readSource.resume()
    }

    func stop() {
        lock.lock()
        stopped = true
        let current = source
        let identity = socketIdentity
        source = nil
        socketIdentity = nil
        lock.unlock()
        // Unlink now so a normal app termination does not depend on a pending
        // cancellation block. Only the serial cancellation handler closes the FD.
        if let identity { Self.removeOwnedSocket(path: configuration.socketURL.path, identity: identity) }
        current?.cancel()
    }

    deinit { stop() }

    private var isStopped: Bool {
        lock.lock(); defer { lock.unlock() }
        return stopped
    }

    static func peerIsAllowed(_ uid: uid_t, effectiveUID: uid_t) -> Bool { uid == effectiveUID }

    private func acceptOne(_ listener: Int32) {
        guard !isStopped else { return }
        let client = accept(listener, nil, nil)
        guard client >= 0 else { return }
        defer { Darwin.close(client) }
        _ = fcntl(client, F_SETFD, FD_CLOEXEC)
        _ = fcntl(client, F_SETFL, 0)
        var noSignal: Int32 = 1
        setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout.size(ofValue: noSignal)))
        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(client, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var uid: uid_t = 0
        var gid: gid_t = 0
        guard getpeereid(client, &uid, &gid) == 0,
              Self.peerIsAllowed(uid, effectiveUID: geteuid()) else { return }
        do {
            let request = try readRequest(client)
            var response: QAAutomationResponse?
            var actionError: Error?
            DispatchQueue.main.sync {
                guard !self.isStopped else { return }
                do { response = try self.response(for: request) } catch { actionError = error }
            }
            if let actionError { throw actionError }
            guard let response else { return }
            if try sendResponse(client, status: 200, json: response.json), let after = response.afterReply {
                DispatchQueue.main.async(execute: after)
            }
        } catch {
            let http = error as? QAAutomationHTTPError
            _ = try? sendResponse(client, status: http?.status ?? 500,
                                  json: ["error": http?.message ?? "QA request failed"])
        }
    }

    func response(for request: Request) throws -> QAAutomationResponse {
        if request.method == "GET" { return QAAutomationResponse(json: state()) }
        return try command(request.json!)
    }

    struct Request {
        let method: String
        let json: [String: Any]?
    }
    static let maximumHeaderBytes = 8 * 1024
    static let maximumBodyBytes = 64 * 1024

    // nil means a bounded, incomplete request. No handler runs until framing and JSON validate.
    static func parseRequest(_ data: Data) throws -> Request? {
        func fail(_ status: Int = 400, _ message: String = "Malformed HTTP request") -> QAAutomationHTTPError {
            QAAutomationHTTPError(status: status, message: message)
        }
        guard let boundary = data.range(of: Data("\r\n\r\n".utf8)) else {
            if data.count > maximumHeaderBytes { throw fail(431, "Headers too large") }
            return nil
        }
        guard boundary.upperBound <= maximumHeaderBytes else { throw fail(431, "Headers too large") }
        guard let header = String(data: data[..<boundary.lowerBound], encoding: .utf8),
              header.utf8.allSatisfy({ $0 == 13 || $0 == 10 || (32...126).contains($0) }) else { throw fail() }
        let lines = header.components(separatedBy: "\r\n")
        let first = lines[0].components(separatedBy: " ")
        guard first.count == 3, first[2] == "HTTP/1.1" else { throw fail() }
        guard first[0] == "GET" || first[0] == "POST" else { throw fail(405, "Unsupported method") }
        guard (first[0] == "GET" && first[1] == "/v1/state") ||
                (first[0] == "POST" && first[1] == "/v1/commands") else { throw fail(404, "Unknown route") }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { throw fail() }
            let name = String(line[..<colon]).lowercased()
            guard !name.isEmpty, name.utf8.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }),
                  headers[name] == nil else { throw fail() }
            headers[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        guard headers["transfer-encoding"] == nil, headers["expect"] == nil,
              let host = headers["host"], !host.isEmpty else { throw fail() }
        let length: Int
        if let value = headers["content-length"] {
            guard !value.isEmpty, value.utf8.allSatisfy({ (48...57).contains($0) }),
                  let parsed = Int(value) else { throw fail() }
            length = parsed
        } else {
            guard first[0] == "GET" else { throw fail(411, "Content-Length required") }
            length = 0
        }
        guard length <= maximumBodyBytes else { throw fail(413, "Body too large") }
        let body = data[boundary.upperBound...]
        guard body.count <= length else { throw fail() }
        guard body.count == length else { return nil }
        if first[0] == "GET" {
            guard length == 0 else { throw fail() }
            return Request(method: "GET", json: nil)
        }
        guard headers["content-type"]?.lowercased() == "application/json",
              String(data: body, encoding: .utf8) != nil,
              let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] else {
            throw fail(400, "Expected a UTF-8 JSON object")
        }
        return Request(method: "POST", json: json)
    }

    private func readRequest(_ descriptor: Int32) throws -> Request {
        var data = Data()
        let deadline = ProcessInfo.processInfo.systemUptime + 3
        var buffer = [UInt8](repeating: 0, count: 4096)
        while !isStopped && ProcessInfo.processInfo.systemUptime < deadline {
            let count = recv(descriptor, &buffer, buffer.count, 0)
            guard count > 0 else { throw QAAutomationHTTPError(status: 408, message: "Incomplete request") }
            data.append(contentsOf: buffer.prefix(count))
            if let request = try Self.parseRequest(data) {
                // Reject additional bytes already queued; this connection is never reused.
                var byte: UInt8 = 0
                if recv(descriptor, &byte, 1, MSG_PEEK | MSG_DONTWAIT) > 0 {
                    throw QAAutomationHTTPError(status: 400, message: "Pipelining is unsupported")
                }
                return request
            }
        }
        throw QAAutomationHTTPError(status: 408, message: "Request timeout")
    }

    private func sendResponse(_ descriptor: Int32, status: Int, json: [String: Any]) throws -> Bool {
        let body = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        guard body.count <= 1024 * 1024 else { throw QAAutomationHTTPError(status: 500, message: "Response too large") }
        var data = Data("HTTP/1.1 \(status) Response\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)
        data.append(body)
        let deadline = ProcessInfo.processInfo.systemUptime + 3
        return data.withUnsafeBytes { bytes in
            var sent = 0
            while sent < bytes.count && ProcessInfo.processInfo.systemUptime < deadline {
                let count = send(descriptor, bytes.baseAddress!.advanced(by: sent), bytes.count - sent, 0)
                guard count > 0 else { return false }
                sent += count
            }
            return sent == bytes.count
        }
    }

    private static func posixError() -> POSIXError { POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }

    private static func removeOwnedSocket(path: String, identity: stat) {
        var current = stat()
        if lstat(path, &current) == 0, (current.st_mode & S_IFMT) == S_IFSOCK,
           current.st_dev == identity.st_dev, current.st_ino == identity.st_ino {
            _ = unlink(path)
        }
    }
}
#endif
