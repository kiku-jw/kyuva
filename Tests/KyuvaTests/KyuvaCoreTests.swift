import XCTest
import Combine
@testable import Kyuva

final class ScriptTextFileTests: XCTestCase {
    func testWriteExportCreatesAReadableUTF8TextFileWithSafeName() throws {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyuvaExportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: baseDirectory) }

        let url = try ScriptTextFile.writeExport(
            name: " Scene/One.TXT ",
            content: "Opening line\n[Smile at camera] 🎥",
            in: baseDirectory
        )

        XCTAssertEqual(url.lastPathComponent, "Scene-One.txt")
        XCTAssertEqual(url.deletingLastPathComponent().deletingLastPathComponent(), baseDirectory)
        XCTAssertEqual(
            try String(contentsOf: url, encoding: .utf8),
            "Opening line\n[Smile at camera] 🎥"
        )
    }

    func testExportNameIsSafeBoundedAndKeepsOneTextExtension() {
        XCTAssertEqual(
            ScriptTextFile.exportName(for: "  Scene/Take:One  .TXT"),
            "Scene-Take-One.txt"
        )
        XCTAssertEqual(ScriptTextFile.exportName(for: "   "), "Kyuva Script.txt")

        let longName = ScriptTextFile.exportName(for: String(repeating: "a", count: 120))
        XCTAssertEqual(longName, String(repeating: "a", count: 80) + ".txt")
    }

    func testDecodeImportAcceptsTheExactByteLimit() throws {
        let data = Data(repeating: 0x61, count: ScriptTextFile.maximumBytes)

        let content = try ScriptTextFile.decodeImport(data)

        XCTAssertEqual(content.utf8.count, ScriptTextFile.maximumBytes)
    }

    func testDecodeImportRejectsOneByteOverTheLimit() {
        let data = Data(repeating: 0x61, count: ScriptTextFile.maximumBytes + 1)

        XCTAssertThrowsError(try ScriptTextFile.decodeImport(data)) { error in
            guard case ScriptTextImportError.fileTooLarge = error else {
                return XCTFail("Expected fileTooLarge, got \(error)")
            }
        }
    }

    func testDecodeImportRejectsInvalidUTF8() {
        XCTAssertThrowsError(try ScriptTextFile.decodeImport(Data([0xC3, 0x28]))) { error in
            guard case ScriptTextImportError.notUTF8 = error else {
                return XCTFail("Expected notUTF8, got \(error)")
            }
        }
    }
}
final class ScriptTests: XCTestCase {
    func testReindexFiltersBlankLinesAndKeepsTokenLineIndexes() {
        var script = Script(
            name: "Token fixture",
            content: "Hello, WORLD!\n\nSwiftUI's camera-side text.\nKyuva"
        )

        XCTAssertEqual(script.lines, [
            "Hello, WORLD!",
            "SwiftUI's camera-side text.",
            "Kyuva"
        ])
        XCTAssertEqual(script.tokens.map(\.word), [
            "hello", "world", "swiftui", "s", "camera", "side", "text", "kyuva"
        ])
        XCTAssertEqual(script.tokens.map(\.lineIndex), [0, 0, 1, 1, 1, 1, 1, 2])
        XCTAssertEqual(script.tokens.filter(\.isAnchor).map(\.word), ["swiftui"])

        script.content = "Updated line\n\nSecond updated line"
        script.reindex()

        XCTAssertEqual(script.lines, ["Updated line", "Second updated line"])
        XCTAssertEqual(script.tokens.map(\.word), ["updated", "line", "second", "updated", "line"])
        XCTAssertEqual(script.tokens.map(\.lineIndex), [0, 0, 1, 1, 1])
    }

    func testPromptLinesRecognizeOnlyCompleteBracketedDirections() {
        let script = Script(
            name: "Directions",
            content: "Opening line\n[Smile at camera]\n(Pause)\n[unfinished\nClosing line"
        )

        XCTAssertEqual(script.promptLines.map(\.text), [
            "Opening line",
            "[Smile at camera]",
            "(Pause)",
            "[unfinished",
            "Closing line"
        ])
        XCTAssertEqual(
            script.promptLines.map(\.isStageDirection),
            [false, true, true, false, false]
        )
        XCTAssertEqual(script.wordCount(excludingStageDirections: false), 9)
        XCTAssertEqual(script.wordCount(excludingStageDirections: true), 5)
    }
}

final class LocalStoreTests: XCTestCase {
    func testScriptsRoundTripThroughInjectedDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyuvaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let queue = DispatchQueue(label: "com.kyuva.tests.local-store")
        let store = LocalStore(directoryURL: directory, saveQueue: queue)
        let script = Script(name: "Round trip", content: "First line\nSecond line")

        store.saveScripts([script])
        store.waitForPendingWrites()

        let loaded = try store.loadScripts()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, script.id)
        XCTAssertEqual(loaded.first?.name, script.name)
        XCTAssertEqual(loaded.first?.content, script.content)
        XCTAssertEqual(loaded.first?.lines, script.lines)
        XCTAssertEqual(loaded.first?.tokens.map(\.word), script.tokens.map(\.word))
    }

    func testCorruptPrimaryRecoversLastKnownGoodBackupAndPreservesEvidence() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyuvaRecoveryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = LocalStore(
            directoryURL: directory,
            saveQueue: DispatchQueue(label: "com.kyuva.tests.recovery-store")
        )
        let lastKnownGood = Script(name: "Recover me", content: "Important local script")
        let newer = Script(name: "Newer", content: "A later valid revision")

        store.saveScripts([lastKnownGood])
        store.waitForPendingWrites()
        store.saveScripts([newer])
        store.waitForPendingWrites()

        let primaryURL = directory.appendingPathComponent("scripts.json")
        try Data("not valid JSON".utf8).write(to: primaryURL, options: .atomic)

        let recovered = try store.loadScripts()
        XCTAssertEqual(recovered.map(\.id), [lastKnownGood.id])
        XCTAssertEqual(recovered.map(\.content), [lastKnownGood.content])

        let preservedFiles = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("scripts.corrupt-") }
        XCTAssertEqual(preservedFiles.count, 1)
        XCTAssertEqual(try Data(contentsOf: preservedFiles[0]), Data("not valid JSON".utf8))
    }
}

final class ScriptManagerPersistenceTests: XCTestCase {
    func testCreateAndDeleteKeepAValidSelectionAndPersist() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyuvaCRUDTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = LocalStore(
            directoryURL: directory,
            saveQueue: DispatchQueue(label: "com.kyuva.tests.crud-store")
        )
        let manager = ScriptManager(storage: store)
        let originalId = try XCTUnwrap(manager.selectedScriptId)

        manager.createNewScript()
        let createdId = try XCTUnwrap(manager.selectedScriptId)
        XCTAssertNotEqual(createdId, originalId)
        XCTAssertEqual(manager.scripts.count, 2)

        let createdIndex = try XCTUnwrap(
            manager.scripts.firstIndex(where: { $0.id == createdId })
        )
        manager.deleteScripts(at: IndexSet(integer: createdIndex))
        manager.flushPendingSave()

        XCTAssertEqual(manager.scripts.map(\.id), [originalId])
        XCTAssertEqual(manager.selectedScriptId, originalId)
        XCTAssertEqual(try LocalStore(directoryURL: directory).loadScripts().map(\.id), [originalId])
    }

    func testFlushPendingSavePersistsTheLatestDebouncedEdit() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyuvaManagerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = LocalStore(
            directoryURL: directory,
            saveQueue: DispatchQueue(label: "com.kyuva.tests.manager-store")
        )
        let manager = ScriptManager(storage: store)
        let scriptId = try XCTUnwrap(manager.selectedScriptId)

        manager.updateScriptName(scriptId, name: "Final name")
        manager.updateScriptContent(scriptId, content: "The final unslept edit")
        manager.flushPendingSave()

        let reloaded = try LocalStore(directoryURL: directory).loadScripts()
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded.first?.name, "Final name")
        XCTAssertEqual(reloaded.first?.content, "The final unslept edit")
    }

    func testImportCreatesSelectsAndPersistsOneScript() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyuvaImportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = LocalStore(
            directoryURL: directory,
            saveQueue: DispatchQueue(label: "com.kyuva.tests.import-store")
        )
        let manager = ScriptManager(storage: store)

        let imported = manager.importScript(name: "  AirDrop Notes  ", content: "First\nSecond")
        manager.flushPendingSave()

        XCTAssertEqual(imported.name, "AirDrop Notes")
        XCTAssertEqual(manager.selectedScriptId, imported.id)
        XCTAssertEqual(manager.scripts.last?.id, imported.id)
        XCTAssertEqual(manager.scripts.last?.content, imported.content)
        let reloaded = try LocalStore(directoryURL: directory).loadScripts().last
        XCTAssertEqual(reloaded?.id, imported.id)
        XCTAssertEqual(reloaded?.content, imported.content)
    }
}

final class ScrollControllerTests: XCTestCase {
    func testResetKeepsManualPauseIntentAfterAutomaticPauseUntilExplicitResume() throws {
        let suiteName = "KyuvaTests.ScrollController.Reset.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let controller = ScrollController(startTimer: false, userDefaults: defaults)
        controller.updateContentMetrics(contentHeight: 1_150, visibleHeight: 150, wordCount: 200)
        controller.resume()
        XCTAssertFalse(controller.isPaused)
        XCTAssertFalse(controller.wasManuallyPaused)
        controller.goToOffset(250)
        controller.highlightedLine = 2

        controller.pause() // The overlay's automatic hover pause.
        XCTAssertFalse(controller.wasManuallyPaused)
        controller.reset()

        XCTAssertEqual(controller.scrollOffset, 0)
        XCTAssertNil(controller.highlightedLine)
        XCTAssertTrue(controller.isPaused)
        XCTAssertTrue(controller.wasManuallyPaused,
                      "Reset must prevent hover exit from resuming playback")

        controller.resume()
        XCTAssertFalse(controller.isPaused)
        XCTAssertFalse(controller.wasManuallyPaused)
    }

    func testSavedScrollSpeedAppliesAtStartupAndWhenDefaultsChange() {
        let suiteName = "KyuvaTests.ScrollController.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(72.5, forKey: "scrollSpeed")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let controller = ScrollController(startTimer: false, userDefaults: defaults)
        XCTAssertEqual(controller.scrollSpeed, 72.5, accuracy: 0.0001)
        XCTAssertEqual(controller.scrollOffset, 0)

        defaults.set(118.25, forKey: "scrollSpeed")
        controller.applyPersistedScrollSpeed(from: defaults)

        XCTAssertEqual(controller.scrollSpeed, 118.25, accuracy: 0.0001)
        XCTAssertEqual(controller.scrollOffset, 0)

        controller.adjustSpeed(delta: 200)
        XCTAssertEqual(controller.scrollSpeed, ScrollController.maximumSpeed)
        XCTAssertEqual(defaults.double(forKey: "scrollSpeed"), ScrollController.maximumSpeed)

        controller.adjustSpeed(delta: -500)
        XCTAssertEqual(controller.scrollSpeed, ScrollController.minimumSpeed)
        XCTAssertEqual(defaults.double(forKey: "scrollSpeed"), ScrollController.minimumSpeed)
    }

    func testWordsPerMinuteDerivesSpeedProgressAndRemainingTime() {
        let suiteName = "KyuvaTests.ScrollController.WPM.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(ScrollPaceMode.wordsPerMinute.rawValue, forKey: ScrollController.paceModeDefaultsKey)
        defaults.set(120, forKey: ScrollController.wordsPerMinuteDefaultsKey)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let controller = ScrollController(startTimer: false, userDefaults: defaults)
        controller.updateContentMetrics(contentHeight: 1_150, visibleHeight: 150, wordCount: 200)

        XCTAssertEqual(controller.paceMode, .wordsPerMinute)
        XCTAssertEqual(controller.scrollSpeed, 10, accuracy: 0.0001)
        XCTAssertEqual(controller.remainingTime ?? -1, 100, accuracy: 0.0001)
        XCTAssertEqual(controller.paceControlLabel, "120w")

        controller.goToOffset(250)
        XCTAssertEqual(controller.progress, 0.25, accuracy: 0.0001)
        XCTAssertEqual(controller.remainingTime ?? -1, 75, accuracy: 0.0001)

        controller.adjustPace(steps: 2)
        XCTAssertEqual(controller.wordsPerMinute, 130, accuracy: 0.0001)
        XCTAssertEqual(defaults.double(forKey: ScrollController.wordsPerMinuteDefaultsKey), 130)
        XCTAssertEqual(controller.scrollSpeed, 10.833_333, accuracy: 0.0001)
    }

    func testApplyingDefaultsSwitchesPaceModeWithoutMovingTheScript() {
        let suiteName = "KyuvaTests.ScrollController.ModeSwitch.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(50, forKey: ScrollController.speedDefaultsKey)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let controller = ScrollController(startTimer: false, userDefaults: defaults)
        controller.updateContentMetrics(contentHeight: 1_150, visibleHeight: 150, wordCount: 200)
        controller.goToOffset(250)

        defaults.set(ScrollPaceMode.wordsPerMinute.rawValue, forKey: ScrollController.paceModeDefaultsKey)
        defaults.set(120, forKey: ScrollController.wordsPerMinuteDefaultsKey)
        controller.applyPersistedScrollSpeed(from: defaults)

        XCTAssertEqual(controller.paceMode, .wordsPerMinute)
        XCTAssertEqual(controller.scrollSpeed, 10, accuracy: 0.0001)
        XCTAssertEqual(controller.scrollOffset, 250)
    }

    func testContentMetricChangesPreservePromptProgress() {
        let suiteName = "KyuvaTests.ScrollController.Geometry.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let controller = ScrollController(startTimer: false, userDefaults: defaults)
        controller.updateContentMetrics(contentHeight: 1_150, visibleHeight: 150, wordCount: 200)
        controller.goToOffset(250)

        controller.updateContentMetrics(contentHeight: 750, visibleHeight: 150, wordCount: 200)
        XCTAssertEqual(controller.progress, 0.25, accuracy: 0.0001)
        XCTAssertEqual(controller.scrollOffset, 150, accuracy: 0.0001)

        controller.updateContentMetrics(contentHeight: 1_650, visibleHeight: 150, wordCount: 200)
        XCTAssertEqual(controller.progress, 0.25, accuracy: 0.0001)
        XCTAssertEqual(controller.scrollOffset, 375, accuracy: 0.0001)
    }

    func testTargetDurationDerivesSpeedAndFasterControlShortensDuration() {
        let suiteName = "KyuvaTests.ScrollController.Duration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(ScrollPaceMode.targetDuration.rawValue, forKey: ScrollController.paceModeDefaultsKey)
        defaults.set(120, forKey: ScrollController.targetDurationDefaultsKey)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let controller = ScrollController(startTimer: false, userDefaults: defaults)
        controller.updateContentMetrics(contentHeight: 750, visibleHeight: 150, wordCount: 100)

        XCTAssertEqual(controller.paceMode, .targetDuration)
        XCTAssertEqual(controller.scrollSpeed, 5, accuracy: 0.0001)
        XCTAssertEqual(controller.remainingTime ?? -1, 120, accuracy: 0.0001)
        XCTAssertEqual(controller.paceControlLabel, "2:00")

        controller.goToOffset(150)
        XCTAssertEqual(controller.progress, 0.25, accuracy: 0.0001)
        XCTAssertEqual(controller.remainingTime ?? -1, 90, accuracy: 0.0001)

        controller.adjustPace(steps: 1)
        XCTAssertEqual(controller.targetDurationSeconds, 90, accuracy: 0.0001)
        XCTAssertEqual(defaults.double(forKey: ScrollController.targetDurationDefaultsKey), 90)
        XCTAssertEqual(controller.scrollSpeed, 6.666_667, accuracy: 0.0001)
    }
}

final class HotkeyDefinitionTests: XCTestCase {
    func testFixedHotkeysHaveUniqueSystemDefinitions() {
        let shortcuts = HotkeyManager.Hotkey.allCases.map(\.shortcut)
        let systemDefinitions = shortcuts.map { "\($0.keyCode)-\($0.modifiers)" }

        XCTAssertEqual(Set(systemDefinitions).count, shortcuts.count)
        XCTAssertEqual(HotkeyManager.Hotkey.togglePause.shortcut.display, "⌃⌥Space")
        XCTAssertEqual(HotkeyManager.Hotkey.toggleVoiceFollow.shortcut.display, "⌃⌥V")
        XCTAssertEqual(HotkeyManager.Hotkey.nextDisplay.shortcut.display, "⌃⌥D")
    }
}

final class WindowDragTrackerTests: XCTestCase {
    func testCumulativeGestureTranslationUsesTheOriginalWindowOrigin() {
        var tracker = WindowDragTracker()
        let start = CGPoint(x: 100, y: 200)

        let first = tracker.origin(
            currentOrigin: start,
            translation: CGPoint(x: 10, y: 5)
        )
        XCTAssertEqual(first, CGPoint(x: 110, y: 195))

        let second = tracker.origin(
            currentOrigin: first,
            translation: CGPoint(x: 20, y: 10)
        )
        XCTAssertEqual(second, CGPoint(x: 120, y: 190))

        tracker.reset()
        let nextGesture = tracker.origin(
            currentOrigin: second,
            translation: CGPoint(x: 5, y: 5)
        )
        XCTAssertEqual(nextGesture, CGPoint(x: 125, y: 185))
    }
}

final class RemoteControlProtocolTests: XCTestCase {
    func testCommandsRoundTripThroughPropertyListMessage() {
        for command in RemoteCommand.allCases {
            XCTAssertEqual(RemoteCommand(message: command.message), command)
        }

        XCTAssertNil(RemoteCommand(message: [:]))
        XCTAssertNil(RemoteCommand(message: ["command": "unknown"] as [String: Any]))
    }

    func testPlaybackSnapshotRoundTripsAndClampsProgress() throws {
        let snapshot = PlaybackSnapshot(
            isPromptActive: true,
            isPaused: false,
            scriptTitle: "Keynote",
            paceLabel: "150w",
            progress: 1.4
        )

        XCTAssertEqual(snapshot.progress, 1)
        XCTAssertEqual(PlaybackSnapshot(message: snapshot.message), snapshot)
        XCTAssertNil(PlaybackSnapshot(message: ["isPaused": true] as [String: Any]))
    }
}

@MainActor
final class ScriptDeliveryScenarioTests: XCTestCase {
    private func fixtureDirectory() throws -> URL {
        let base = ProcessInfo.processInfo.environment["KYUVA_TEST_DIRECTORY"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("KyuvaFlow-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func drainMainCallbacks() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    func testUTF8ImportEditFlushAndReopenKeepsIdentityAndLatestRevision() async throws {
        let directory = try fixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("Виступ — 東京.txt")
        let bytes = Data("Вітаю, світе 🙂\n[Пауза]\nHello, everyone.\n(Pause)".utf8)
        try bytes.write(to: input)
        let store = LocalStore(directoryURL: directory.appendingPathComponent("library"))
        let manager = ScriptManager(storage: store)
        let imported = manager.importScript(name: input.deletingPathExtension().lastPathComponent,
            content: try ScriptTextFile.decodeImport(Data(contentsOf: input)))
        let editedTitle = "Final — Виступ / 東京"
        let editedText = imported.content + "\nمرحبا — Closing words."
        manager.updateScriptName(imported.id, name: editedTitle)
        manager.updateScriptContent(imported.id, content: editedText)
        XCTAssertEqual(manager.saveState, .pending)
        store.waitForPendingWrites()
        await drainMainCallbacks()
        XCTAssertEqual(manager.saveState, .pending, "Earlier completed writes cannot mark the newest edit saved")
        try manager.flushPendingSave().get()
        XCTAssertEqual(manager.saveState, .saved)
        await drainMainCallbacks()
        XCTAssertEqual(manager.saveState, .saved, "Older callbacks cannot overwrite the flushed revision")

        let reopened = ScriptManager(storage: LocalStore(directoryURL: directory.appendingPathComponent("library")))
        let restored = try XCTUnwrap(reopened.scripts.first { $0.id == imported.id })
        XCTAssertEqual(restored.id, imported.id)
        XCTAssertEqual(restored.name, editedTitle)
        XCTAssertEqual(Data(restored.content.utf8), Data(editedText.utf8))
        XCTAssertEqual(restored.promptLines.filter(\.isStageDirection).map(\.text), ["[Пауза]", "(Pause)"])
        XCTAssertEqual(try Data(contentsOf: input), bytes)
    }

    func testRealTimerPlayPauseResetUsesIsolatedPaceAndPersistedScript() async throws {
        let directory = try fixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = ScriptManager(storage: LocalStore(directoryURL: directory))
        let imported = manager.importScript(name: "Controlled delivery", content: "Opening words\n[Look up]\nClosing words")
        try manager.flushPendingSave().get()
        let suite = "KyuvaTests.Flow.Timer.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(80, forKey: ScrollController.speedDefaultsKey)
        let controller = ScrollController(startTimer: true, userDefaults: defaults)
        // Stay far from the end: tick never reads its standard-domain endBehavior
        // and the test does not mutate that preference or start speech.
        controller.updateContentMetrics(contentHeight: 10_150, visibleHeight: 150,
            wordCount: imported.wordCount(excludingStageDirections: true))
        let advanced = expectation(description: "Actual scroll timer advances")
        var fulfilled = false
        let observation = controller.$scrollOffset.sink { value in
            if value > 0 && !fulfilled { fulfilled = true; advanced.fulfill() }
        }
        controller.resume()
        XCTAssertFalse(controller.isPaused)
        await fulfillment(of: [advanced], timeout: 2)
        controller.manualPause()
        let pausedOffset = controller.scrollOffset
        XCTAssertGreaterThan(pausedOffset, 0)
        XCTAssertTrue(controller.wasManuallyPaused)
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(controller.scrollOffset, pausedOffset)
        controller.reset()
        XCTAssertEqual(controller.scrollOffset, 0)
        XCTAssertTrue(controller.isPaused)
        XCTAssertNil(controller.highlightedLine)
        withExtendedLifetime(observation) {}
        XCTAssertEqual(try LocalStore(directoryURL: directory).loadScripts().last?.id, imported.id)
    }

    func testWriteFailureIsVisibleThenRetryPreservesOriginalAndBackup() async throws {
        let directory = try fixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalStore(directoryURL: directory)
        let original = Script(name: "Original — збережено", content: "Original words\n[Pause]")
        store.saveScripts([original]); try store.waitForPendingWrites().get()
        store.saveScripts([original]); try store.waitForPendingWrites().get()
        let primary = directory.appendingPathComponent("scripts.json")
        let backup = directory.appendingPathComponent("scripts.backup.json")
        let preservedBackup = directory.appendingPathComponent("preserved-backup.json")
        let primaryBytes = try Data(contentsOf: primary)
        let backupBytes = try Data(contentsOf: backup)
        try FileManager.default.moveItem(at: backup, to: preservedBackup)
        try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: false)
        let manager = ScriptManager(storage: store)
        let edited = "New revision — нові слова 🙂\n[Look up]"
        manager.updateScriptContent(original.id, content: edited)
        let result = manager.flushPendingSave()
        guard case .failure = result else { return XCTFail("Blocked write must report failure") }
        guard case .failed(let message) = manager.saveState else { return XCTFail("Manager must expose Not saved state") }
        XCTAssertFalse(message.isEmpty)
        XCTAssertEqual(manager.selectedScript?.content, edited)
        XCTAssertEqual(try Data(contentsOf: primary), primaryBytes)
        XCTAssertEqual(try Data(contentsOf: preservedBackup), backupBytes)
        XCTAssertEqual(try LocalStore(directoryURL: directory).loadScripts().first?.content, original.content)

        try FileManager.default.removeItem(at: backup)
        try FileManager.default.copyItem(at: preservedBackup, to: backup)
        let saved = expectation(description: "Explicit retry reports durable success")
        var fulfilled = false
        let observation = manager.$saveState.sink { state in
            if state == .saved && !fulfilled { fulfilled = true; saved.fulfill() }
        }
        manager.retrySave()
        XCTAssertEqual(manager.saveState, .saving)
        await fulfillment(of: [saved], timeout: 2)
        withExtendedLifetime(observation) {}
        XCTAssertEqual(manager.saveState, .saved)
        let restored = try XCTUnwrap(try LocalStore(directoryURL: directory).loadScripts().first)
        XCTAssertEqual(restored.id, original.id)
        XCTAssertEqual(restored.name, original.name)
        XCTAssertEqual(restored.content, edited)
        XCTAssertEqual(try Data(contentsOf: backup), primaryBytes)
        XCTAssertEqual(try Data(contentsOf: preservedBackup), backupBytes)
    }

    func testExportReadbackPreservesUnicodeDirectionsAndInputBytes() throws {
        let directory = try fixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("input.txt")
        let bytes = Data("Café e\u{301} — Україна 🙂\r\n[Погляд у камеру]\r\nمرحبا\n(Pause)\n東京".utf8)
        try bytes.write(to: input)
        let manager = ScriptManager(storage: LocalStore(directoryURL: directory.appendingPathComponent("library")))
        let script = manager.importScript(name: "Виступ/東京", content: try ScriptTextFile.decodeImport(Data(contentsOf: input)))
        try manager.flushPendingSave().get()
        let output = try ScriptTextFile.writeExport(name: script.name, content: script.content,
            in: directory.appendingPathComponent("exports"))
        XCTAssertEqual(try Data(contentsOf: output), bytes)
        XCTAssertEqual(try Data(contentsOf: input), bytes)
        let reopened = try XCTUnwrap(try LocalStore(directoryURL: directory.appendingPathComponent("library"))
            .loadScripts().first { $0.id == script.id })
        XCTAssertEqual(Data(reopened.content.utf8), bytes)
        XCTAssertEqual(reopened.promptLines.filter(\.isStageDirection).map(\.text), ["[Погляд у камеру]", "(Pause)"])
    }
}

final class QAStorageRoutingTests: XCTestCase {
    func testQABundleRequiresAndSelectsExplicitAbsoluteFixtureDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyuvaQARoute-\(UUID().uuidString)", isDirectory: true)
        let selected = try LocalStore.qaStorageDirectory(
            bundleIdentifier: "com.kikuai.kyuva.qa20261115", fixturePath: directory.path
        )
        XCTAssertEqual(selected, directory.standardizedFileURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path), "Selection must not create directories")
    }

    func testNonQABundleDoesNotSelectOrRequireQAFixturePath() throws {
        XCTAssertNil(try LocalStore.qaStorageDirectory(bundleIdentifier: "com.kikuai.kyuva", fixturePath: nil))
        XCTAssertNil(try LocalStore.qaStorageDirectory(bundleIdentifier: "com.other.product", fixturePath: "relative"))
    }

    func testQABundleMissingFixtureKeyFailsClosed() {
        XCTAssertThrowsError(try LocalStore.qaStorageDirectory(
            bundleIdentifier: "com.kikuai.kyuva.qa20261115", fixturePath: nil
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("KyuvaQAStorageDirectory"))
        }
    }

    func testQABundleRelativeOrInvalidFixtureKeyFailsClosed() {
        for path in ["", "relative/scripts", "~/scripts", "file:///tmp/fixture", "/tmp/invalid\0path"] {
            XCTAssertThrowsError(try LocalStore.qaStorageDirectory(
                bundleIdentifier: "com.kikuai.kyuva.qa20261115", fixturePath: path
            ), "Invalid QA path must never select an environment/default fallback: \(path)")
        }
    }
}

@MainActor
final class LoadRecoverySafetyTests: XCTestCase {
    private func directory() throws -> URL {
        let root = ProcessInfo.processInfo.environment["KYUVA_TEST_DIRECTORY"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory
        let directory = root.appendingPathComponent("load-safety-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func drainCallbacks() async {
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
    }

    private func requireReadDenial(_ path: URL) throws {
        var readError: NSError?
        do { _ = try Data(contentsOf: path) } catch { readError = error as NSError }
        guard let readError else { throw XCTSkip("This process can read mode000; permission-denial case is NOT_RUN") }
        XCTAssertEqual(readError.domain, NSCocoaErrorDomain)
        XCTAssertEqual(readError.code, CocoaError.fileReadNoPermission.rawValue)
    }

    func testBothCorruptStartupDoesNotSeedOrOverwriteExistingFiles() async throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let primary = dir.appendingPathComponent("scripts.json")
        let backup = dir.appendingPathComponent("scripts.backup.json")
        let oldPrimary = Data("{generated unreadable JSON primary".utf8)
        let oldBackup = Data("[generated unreadable JSON backup".utf8)
        try oldPrimary.write(to: primary); try oldBackup.write(to: backup)
        let store = LocalStore(directoryURL: dir)
        let manager = ScriptManager(storage: store)
        store.waitForPendingWrites(); await drainCallbacks()
        XCTAssertTrue(manager.scripts.isEmpty, "Failed existing load must not seed a default draft")
        XCTAssertEqual(try Data(contentsOf: primary), oldPrimary)
        XCTAssertEqual(try Data(contentsOf: backup), oldBackup)
    }

    func testActualDeniedReadsCannotBecomeStartupReplacementWrites() async throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let primary = dir.appendingPathComponent("scripts.json")
        let backup = dir.appendingPathComponent("scripts.backup.json")
        let old = try JSONEncoder().encode([Script(name: "Generated words", content: "Original — Україна 🙂")])
        try old.write(to: primary); try old.write(to: backup)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: primary.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: backup.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: primary.path)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
        }
        try requireReadDenial(primary); try requireReadDenial(backup)
        let before = try FileManager.default.attributesOfItem(atPath: primary.path)
        let store = LocalStore(directoryURL: dir)
        let manager = ScriptManager(storage: store)
        store.waitForPendingWrites(); await drainCallbacks()
        let after = try FileManager.default.attributesOfItem(atPath: primary.path)
        XCTAssertTrue(manager.scripts.isEmpty, "Actual denied reads must not create a New Script")
        for key in [FileAttributeKey.size, .modificationDate, .posixPermissions, .systemFileNumber] {
            XCTAssertEqual(String(describing: after[key]), String(describing: before[key]), "Primary metadata changed: \(key)")
        }
        // Restore only this new synthetic fixture to verify exact bytes and clean up.
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: primary.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
        XCTAssertEqual(try Data(contentsOf: primary), old)
        XCTAssertEqual(try Data(contentsOf: backup), old)
    }

    func testFreshAndValidEmptyLibrariesRemainUseful() throws {
        for existingEmpty in [false, true] {
            let dir = try directory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let primary = dir.appendingPathComponent("scripts.json")
            if existingEmpty { try Data("[]".utf8).write(to: primary) }
            let store = LocalStore(directoryURL: dir)
            XCTAssertTrue(try store.loadScripts().isEmpty)
            let manager = ScriptManager(storage: store)
            XCTAssertNil(manager.loadError)
            XCTAssertEqual(manager.scripts.count, 1)
            try manager.flushPendingSave().get()
            XCTAssertEqual(try store.loadScripts().first?.id, manager.scripts.first?.id)
        }
    }

    func testPopulatedReopenUsesValidPrimaryWithoutDependingOnBadBackup() throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let script = Script(name: "Existing", content: "Preserve every word — 🙂")
        let bytes = try JSONEncoder().encode([script])
        let primary = dir.appendingPathComponent("scripts.json")
        let backup = dir.appendingPathComponent("scripts.backup.json")
        try bytes.write(to: primary); try Data("bad backup".utf8).write(to: backup)
        for _ in 0..<2 {
            let manager = ScriptManager(storage: LocalStore(directoryURL: dir))
            XCTAssertNil(manager.loadError)
            XCTAssertEqual(manager.selectedScript?.id, script.id)
            XCTAssertEqual(manager.selectedScript?.content, script.content)
            XCTAssertEqual(manager.saveState, .saved)
        }
        XCTAssertEqual(try Data(contentsOf: primary), bytes)
        XCTAssertEqual(try Data(contentsOf: backup), Data("bad backup".utf8))
    }

    func testRecoveredBackupRequiresPreservedPrimaryAndCanLaterSave() throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let primary = dir.appendingPathComponent("scripts.json")
        let backup = dir.appendingPathComponent("scripts.backup.json")
        let corrupt = Data("{preserve exact generated original".utf8)
        let script = Script(name: "Recovered", content: "Recovered words")
        let valid = try JSONEncoder().encode([script])
        try corrupt.write(to: primary); try valid.write(to: backup)
        let manager = ScriptManager(storage: LocalStore(directoryURL: dir))
        XCTAssertNil(manager.loadError)
        XCTAssertEqual(manager.selectedScript?.id, script.id)
        XCTAssertEqual(try Data(contentsOf: primary), corrupt)
        let copies = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("scripts.corrupt-") }
        XCTAssertTrue(try copies.contains { try Data(contentsOf: $0) == corrupt })
        manager.updateScriptContent(script.id, content: "Edited recovered words")
        try manager.flushPendingSave().get()
        XCTAssertEqual(try LocalStore(directoryURL: dir).loadScripts().first?.content, "Edited recovered words")
        XCTAssertEqual(try Data(contentsOf: backup), valid)
        XCTAssertTrue(try copies.allSatisfy { try Data(contentsOf: $0) == corrupt })
    }

    func testExistingSingleCorruptFileIsNotAConfirmedFreshLibrary() throws {
        for name in ["scripts.json", "scripts.backup.json"] {
            let dir = try directory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let file = dir.appendingPathComponent(name)
            let bytes = Data("generated corrupt storage".utf8)
            try bytes.write(to: file)
            let manager = ScriptManager(storage: LocalStore(directoryURL: dir))
            XCTAssertNotNil(manager.loadError)
            XCTAssertTrue(manager.scripts.isEmpty)
            XCTAssertThrowsError(try manager.flushPendingSave().get())
            XCTAssertEqual(try Data(contentsOf: file), bytes)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path), [name])
        }
    }

    func testDirectoryCreationFailureIsVisibleAndRetryOpeningRecovers() throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let blocked = dir.appendingPathComponent("library")
        let blocker = Data("generated directory blocker".utf8)
        try blocker.write(to: blocked)
        let manager = ScriptManager(storage: LocalStore(directoryURL: blocked))
        XCTAssertNotNil(manager.loadError)
        XCTAssertTrue(manager.scripts.isEmpty)
        XCTAssertThrowsError(try manager.flushPendingSave().get())
        XCTAssertEqual(try Data(contentsOf: blocked), blocker)
        try FileManager.default.removeItem(at: blocked)
        try FileManager.default.createDirectory(at: blocked, withIntermediateDirectories: false)
        let restored = Script(name: "Repaired library", content: "Existing restored text")
        let bytes = try JSONEncoder().encode([restored])
        try bytes.write(to: blocked.appendingPathComponent("scripts.json"))
        manager.retryOpening()
        XCTAssertNil(manager.loadError)
        XCTAssertEqual(manager.selectedScript?.id, restored.id)
        XCTAssertEqual(manager.saveState, .saved)
        XCTAssertEqual(try Data(contentsOf: blocked.appendingPathComponent("scripts.json")), bytes)
    }

    func testFailedOpeningRetryPreservesDraftsAndResumesValidatedAutosave() async throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let primary = dir.appendingPathComponent("scripts.json")
        let corrupt = Data("bad generated primary".utf8)
        try corrupt.write(to: primary)
        let store = LocalStore(directoryURL: dir)
        let manager = ScriptManager(storage: store)
        let draft = manager.importScript(name: "Retained draft", content: "Never discard these words")
        manager.retrySave() // Uses the opening/revalidation route, not a write.
        XCTAssertNotNil(manager.loadError)
        XCTAssertEqual(manager.selectedScript?.id, draft.id)
        guard case .failed = manager.saveState else { return XCTFail("Opening failure must remain visible with drafts") }
        XCTAssertEqual(try Data(contentsOf: primary), corrupt)
        let existing = Script(name: "Existing repaired", content: "Original disk words")
        let repaired = try JSONEncoder().encode([existing])
        try repaired.write(to: primary)
        manager.retryOpening()
        XCTAssertNil(manager.loadError)
        XCTAssertEqual(Set(manager.scripts.map(\.id)), [existing.id, draft.id])
        XCTAssertEqual(manager.selectedScript?.id, draft.id)
        XCTAssertEqual(manager.saveState, .pending, "Loading alone cannot mark retained drafts saved")
        XCTAssertEqual(try Data(contentsOf: primary), repaired)
        let saved = expectation(description: "Validated autosave saves retained drafts")
        var fulfilled = false
        let observation = manager.$saveState.sink { state in
            if state == .saved && !fulfilled { fulfilled = true; saved.fulfill() }
        }
        await fulfillment(of: [saved], timeout: 3)
        withExtendedLifetime(observation) {}
        let reopened = try LocalStore(directoryURL: dir).loadScripts()
        XCTAssertEqual(Set(reopened.map(\.id)), [existing.id, draft.id])
        XCTAssertEqual(reopened.first { $0.id == draft.id }?.content, draft.content)
    }

    func testSuspendedQueueRevalidatesReadDenialAndKeepsNewestDraftOnRetry() async throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let primary = dir.appendingPathComponent("scripts.json")
        let backup = dir.appendingPathComponent("scripts.backup.json")
        let original = Script(name: "Queue safety", content: "Original words")
        let bytes = try JSONEncoder().encode([original])
        try bytes.write(to: primary); try bytes.write(to: backup)
        let queue = DispatchQueue(label: "kyuva.tests.suspended-load")
        queue.suspend()
        var resumed = false
        defer { if !resumed { queue.resume() } }
        let store = LocalStore(directoryURL: dir, saveQueue: queue)
        let manager = ScriptManager(storage: store) // Must not queue.sync here.
        manager.updateScriptContent(original.id, content: "Earlier queued draft")
        manager.retrySave()
        manager.updateScriptContent(original.id, content: "Newest retained draft")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: primary.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: primary.path) }
        try requireReadDenial(primary)
        let before = try FileManager.default.attributesOfItem(atPath: primary.path)
        queue.resume(); resumed = true
        XCTAssertThrowsError(try store.waitForPendingWrites().get())
        await drainCallbacks()
        XCTAssertEqual(manager.saveState, .pending, "Old failure cannot overwrite newest draft state")
        XCTAssertThrowsError(try manager.flushPendingSave().get())
        let after = try FileManager.default.attributesOfItem(atPath: primary.path)
        for key in [FileAttributeKey.size, .modificationDate, .posixPermissions, .systemFileNumber] {
            XCTAssertEqual(String(describing: after[key]), String(describing: before[key]))
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: primary.path)
        XCTAssertEqual(try Data(contentsOf: primary), bytes)
        XCTAssertEqual(try Data(contentsOf: backup), bytes)
        XCTAssertEqual(manager.selectedScript?.content, "Newest retained draft")
        manager.retrySave()
        try store.waitForPendingWrites().get()
        await drainCallbacks()
        XCTAssertEqual(manager.saveState, .saved)
        XCTAssertEqual(try LocalStore(directoryURL: dir).loadScripts().first?.content, "Newest retained draft")
    }

    func testDirectSaveWithoutLoadCannotReplaceBothInvalidFiles() throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let primary = dir.appendingPathComponent("scripts.json")
        let backup = dir.appendingPathComponent("scripts.backup.json")
        let bytes = Data("corrupt original".utf8)
        try bytes.write(to: primary); try bytes.write(to: backup)
        let store = LocalStore(directoryURL: dir)
        store.saveScripts([Script(name: "Unsafe replacement", content: "Must not replace files")])
        XCTAssertThrowsError(try store.waitForPendingWrites().get())
        XCTAssertEqual(try Data(contentsOf: primary), bytes)
        XCTAssertEqual(try Data(contentsOf: backup), bytes)
    }

    func testReadableCorruptPrimaryCannotRecoverWhenPreservationIsDenied() throws {
        let dir = try directory()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
            try? FileManager.default.removeItem(at: dir)
        }
        let primary = dir.appendingPathComponent("scripts.json")
        let backup = dir.appendingPathComponent("scripts.backup.json")
        let corrupt = Data("readable generated corruption".utf8)
        let valid = try JSONEncoder().encode([Script(name: "Backup", content: "Preserved backup words")])
        try corrupt.write(to: primary); try valid.write(to: backup)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: dir.path)
        let probe = dir.appendingPathComponent("new-write-probe")
        var denied = false
        do { try Data().write(to: probe) } catch { denied = true }
        if !denied {
            try? FileManager.default.removeItem(at: probe)
            throw XCTSkip("This process can create files despite0500; preservation-denial case NOT_RUN")
        }
        let manager = ScriptManager(storage: LocalStore(directoryURL: dir))
        XCTAssertNotNil(manager.loadError)
        XCTAssertTrue(manager.scripts.isEmpty)
        XCTAssertThrowsError(try manager.flushPendingSave().get())
        XCTAssertEqual(try Data(contentsOf: primary), corrupt)
        XCTAssertEqual(try Data(contentsOf: backup), valid)
    }

}
