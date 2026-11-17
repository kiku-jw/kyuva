#if DEBUG
import XCTest
import Darwin
@testable import Kyuva

final class QAAutomationSocketTests: XCTestCase {
    private let bundle = "com.kikuai.kyuva.qa.api.t"

    private func fixture() throws -> (URL, String, String) {
        // Keep Darwin's 104-byte AF_UNIX path limit, without a literal user name.
        let realHome = String(cString: getpwuid(getuid())!.pointee.pw_dir)
        let taskRoot = URL(fileURLWithPath: realHome).appendingPathComponent("Developer/tasks", isDirectory: true)
        try FileManager.default.createDirectory(at: taskRoot, withIntermediateDirectories: true)
        var pattern = Array((taskRoot.path + "/qXXXXXX").utf8CString)
        guard mkdtemp(&pattern) != nil else { throw POSIXError(.EIO) }
        let base = URL(fileURLWithPath: String(cString: pattern))
        let home = base.path + "/Library/Containers/\(bundle)/Data"
        try FileManager.default.createDirectory(atPath: home + "/tmp", withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        return (base, home, home + "/tmp/KyuvaAutomation/scripts")
    }

    private func resolve(_ home: String, _ storage: String) throws -> QAAutomationConfiguration {
        guard let result = try QAAutomationConfiguration.resolve(bundleIdentifier: bundle, enabled: true,
                                                                storagePath: storage, homeDirectory: home) else {
            throw QAAutomationHTTPError(status: 500, message: "Enabled test configuration missing")
        }
        return result
    }

    func testDisabledDoesNotValidateOrCreateAnything() throws {
        let path = "/private/tmp/kyuva-disabled-\(UUID().uuidString)"
        XCTAssertNil(try QAAutomationConfiguration.resolve(bundleIdentifier: nil, enabled: false,
                                                         storagePath: path, homeDirectory: "bad\0path"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }

    func testOnlyExactOwnQASandboxStorageIsAcceptedWithoutCreatingIt() throws {
        let (base, home, storage) = try fixture()
        defer { try? FileManager.default.removeItem(at: base) }
        let config = try resolve(home, storage)
        XCTAssertEqual(config.storageURL.path, storage)
        XCTAssertEqual(config.socketURL.path, home + "/tmp/ka/a.sock")
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage))
        XCTAssertFalse(FileManager.default.fileExists(atPath: home + "/tmp/ka"))
        XCTAssertThrowsError(try QAAutomationConfiguration.resolve(bundleIdentifier: "com.kikuai.kyuva",
                                                                 enabled: true, storagePath: storage, homeDirectory: home))
        for invalid in [storage + "/other", home + "/Library/Application Support/Kyuva", storage + "/../scripts", "relative", storage + "\0"] {
            XCTAssertThrowsError(try resolve(home, invalid))
        }
        XCTAssertThrowsError(try resolve(home + "/other", storage))
        XCTAssertThrowsError(try resolve("relative/Library/Containers/\(bundle)/Data", storage))
        let longHome = "/" + String(repeating: "x", count: 100) + "/Library/Containers/\(bundle)/Data"
        XCTAssertThrowsError(try resolve(longHome, longHome + "/tmp/KyuvaAutomation/scripts"))
    }

    func testSymlinkComponentIsRejectedAndTargetUntouched() throws {
        let (base, home, storage) = try fixture()
        defer { try? FileManager.default.removeItem(at: base) }
        let target = base.appendingPathComponent("sentinel")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(atPath: home + "/tmp/KyuvaAutomation", withDestinationPath: target.path)
        XCTAssertThrowsError(try resolve(home, storage))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: target.path), [])
    }

    func testLinkedPrimaryAndBackupCannotEscapeOwnLibrary() throws {
        for leaf in ["scripts.json", "scripts.backup.json"] {
            let (base, home, storage) = try fixture()
            defer { try? FileManager.default.removeItem(at: base) }
            try FileManager.default.createDirectory(atPath: storage, withIntermediateDirectories: true)
            let sentinel = base.appendingPathComponent("generated-sentinel.json")
            let original = Data("generated private sentinel, never a script".utf8)
            try original.write(to: sentinel)
            try FileManager.default.createSymbolicLink(atPath: storage + "/" + leaf, withDestinationPath: sentinel.path)
            XCTAssertThrowsError(try resolve(home, storage))
            XCTAssertEqual(try Data(contentsOf: sentinel), original)
        }
    }

    func testExistingSocketPathFileIsPreserved() throws {
        let (base, home, storage) = try fixture()
        defer { try? FileManager.default.removeItem(at: base) }
        let config = try resolve(home, storage)
        try FileManager.default.createDirectory(at: config.socketURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let sentinel = Data("generated sentinel".utf8)
        try sentinel.write(to: config.socketURL)
        let server = QAAutomationSocket(configuration: config, state: { [:] }, command: { _ in
            XCTFail("Collision must never invoke commands")
            return QAAutomationResponse(json: [:])
        })
        XCTAssertThrowsError(try server.start())
        server.stop()
        XCTAssertEqual(try Data(contentsOf: config.socketURL), sentinel)
    }

    func testSecondServerCannotReplaceLiveSocketAndStopPreservesReplacement() async throws {
        let (base, home, storage) = try fixture()
        defer { try? FileManager.default.removeItem(at: base) }
        let config = try resolve(home, storage)
        let server = QAAutomationSocket(configuration: config, state: { [:] }, command: { _ in QAAutomationResponse(json: [:]) })
        try server.start()
        let other = QAAutomationSocket(configuration: config, state: { [:] }, command: { _ in QAAutomationResponse(json: [:]) })
        XCTAssertThrowsError(try other.start())
        var attributes = try FileManager.default.attributesOfItem(atPath: config.socketURL.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        try FileManager.default.removeItem(at: config.socketURL)
        let sentinel = Data("replacement must survive stop".utf8)
        try sentinel.write(to: config.socketURL)
        server.stop()
        // Cancellation is asynchronous and must never block the main thread.
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(try Data(contentsOf: config.socketURL), sentinel)
        attributes = try FileManager.default.attributesOfItem(atPath: config.socketURL.deletingLastPathComponent().path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o700)
    }

    func testNormalStopRemovesOwnedSocketImmediatelyAndIsIdempotent() throws {
        let (base, home, storage) = try fixture()
        defer { try? FileManager.default.removeItem(at: base) }
        let config = try resolve(home, storage)
        let server = QAAutomationSocket(configuration: config, state: { [:] }, command: { _ in QAAutomationResponse(json: [:]) })
        try server.start()
        XCTAssertTrue(FileManager.default.fileExists(atPath: config.socketURL.path))
        server.stop()
        server.stop()
        XCTAssertFalse(FileManager.default.fileExists(atPath: config.socketURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage))
    }

    private func request(_ method: String = "POST", path: String = "/v1/commands", body: Data = Data("{}".utf8), extra: String = "") -> Data {
        var data = Data("\(method) \(path) HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\n\(extra)\r\n".utf8)
        data.append(body)
        return data
    }

    func testValidGETCannotInvokeCommandAndPOSTParsesMultilingualJSON() throws {
        let (base, home, storage) = try fixture()
        defer { try? FileManager.default.removeItem(at: base) }
        var calls = 0
        let server = QAAutomationSocket(configuration: try resolve(home, storage), state: { ["snapshot": true] }, command: { _ in
            calls += 1
            return QAAutomationResponse(json: [:])
        })
        let get = try XCTUnwrap(QAAutomationSocket.parseRequest(Data("GET /v1/state HTTP/1.1\r\nHost: localhost\r\n\r\n".utf8)))
        let response = try server.response(for: get)
        XCTAssertEqual(response.json["snapshot"] as? Bool, true)
        XCTAssertEqual(calls, 0)
        let body = try JSONSerialization.data(withJSONObject: ["text": "Вітаю! Hello 🌍"])
        let post = try XCTUnwrap(QAAutomationSocket.parseRequest(request(body: body)))
        XCTAssertEqual(post.json?["text"] as? String, "Вітаю! Hello 🌍")
    }

    func testRejectsAmbiguousFramingUnsupportedRoutesMethodsAndJSON() {
        let invalid: [Data] = [
            request("DELETE"), request(path: "/private-file"), request("GET", path: "/v1/commands"),
            request(extra: "Content-Length: 2\r\n"), request(extra: "Transfer-Encoding: chunked\r\n"),
            request(extra: "Expect: 100-continue\r\n"), request(extra: "Host: second\r\n"),
            request(body: Data("[]".utf8)), request(body: Data("broken".utf8)), request(body: Data([0xff])),
            Data("POST /v1/commands HTTP/1.1\r\nHost: localhost\r\nContent-Length: -1\r\n\r\n".utf8),
            Data("POST /v1/commands HTTP/1.1\r\nHost: localhost\r\n\r\n".utf8),
            Data("GET /v1/state HTTP/1.1\r\nHost: localhost\r\nContent-Length: 1\r\n\r\nx".utf8),
            request() + Data("GET /v1/state HTTP/1.1\r\n\r\n".utf8)
        ]
        for bytes in invalid { XCTAssertThrowsError(try QAAutomationSocket.parseRequest(bytes)) }
    }

    func testIncompleteAndOversizeRequestsStayBounded() throws {
        XCTAssertNil(try QAAutomationSocket.parseRequest(Data("GET /v1/state HTTP/1.1\r\n".utf8)))
        XCTAssertNil(try QAAutomationSocket.parseRequest(request().dropLast()))
        XCTAssertThrowsError(try QAAutomationSocket.parseRequest(Data(repeating: 65, count: QAAutomationSocket.maximumHeaderBytes + 1)))
        let oversized = Data("POST /v1/commands HTTP/1.1\r\nHost: localhost\r\nContent-Length: \(QAAutomationSocket.maximumBodyBytes + 1)\r\n\r\n".utf8)
        XCTAssertThrowsError(try QAAutomationSocket.parseRequest(oversized))
    }

    func testPeerMustMatchEffectiveUID() {
        XCTAssertTrue(QAAutomationSocket.peerIsAllowed(501, effectiveUID: 501))
        XCTAssertFalse(QAAutomationSocket.peerIsAllowed(502, effectiveUID: 501))
    }
}
#endif
