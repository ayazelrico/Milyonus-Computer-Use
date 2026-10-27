import Foundation
import Darwin
import ComputerUseContracts
import ComputerUseCore

/// Only the standalone self-test executable exposes this child-process entry point.
enum JournalCrashFixture {
    static let flag = "--journal-crash-child"
    static let stages: [(String, JournalWriteStage)] = [
        ("file-sync", .beforeFileSync), ("rename", .beforeRename), ("directory-sync", .beforeDirectorySync)
    ]
    static func request(key: String = "target") -> ActionRequest {
        ActionRequest(requestId: key, sessionId: "crash-fixture", idempotencyKey: key,
                      observationId: "observation", generation: 1, elementId: "element",
                      kind: .setValue, text: "crash-fixture-private-text")
    }
    static func result(key: String = "target") -> ActionResult {
        ActionResult(requestId: key, actionId: "result-" + key, effect: .applied, verification: .passed)
    }
    static func runChildIfRequested() throws {
        guard CommandLine.arguments.dropFirst().first == flag else { return }
        let args = CommandLine.arguments
        guard args.count == 5, ["intent", "completion"].contains(args[3]),
              let stage = stages.first(where: { $0.0 == args[4] })?.1 else { exit(64) }
        let directory = URL(fileURLWithPath: args[2], isDirectory: true)
        let lease = try ProcessLease(url: directory.appendingPathComponent("writer.lock"))
        var armed = false
        let ledger = try ActionLedger(url: directory.appendingPathComponent("journal.json"), writeCheckpoint: {
            if armed && $0 == stage {
                // SIGKILL skips Swift defer and process-exit cleanup.
                kill(getpid(), SIGKILL)
                _exit(70)
            }
        })
        try ledger.begin(request(key: "baseline"))
        try ledger.finish(request(key: "baseline"), result: result(key: "baseline"))
        armed = args[3] == "intent"
        try ledger.begin(request())
        armed = true
        try ledger.finish(request(), result: result())
        withExtendedLifetime(lease) {}
        exit(71) // A selected checkpoint must terminate the process before here.
    }
}

@MainActor
final class JournalCrashTests: TestCase {
    func runMatrix(phase: String) async throws {
        for (name, _) in JournalCrashFixture.stages {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
            let child = Process()
            child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
            child.arguments = [JournalCrashFixture.flag, directory.path, phase, name]
            child.environment = ["PATH": "/usr/bin:/bin", "TMPDIR": NSTemporaryDirectory()]
            child.standardInput = FileHandle.nullDevice
            child.standardOutput = FileHandle.nullDevice
            child.standardError = FileHandle.nullDevice
            try child.run()
            defer {
                if child.isRunning { kill(child.processIdentifier, SIGKILL); child.waitUntilExit() }
            }
            let deadline = ContinuousClock.now.advanced(by: .seconds(10))
            while child.isRunning && ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            let timedOut = child.isRunning
            if timedOut { kill(child.processIdentifier, SIGKILL) }
            child.waitUntilExit()
            expectFalse(timedOut)
            expectEqual(child.terminationReason, .uncaughtSignal)
            expectEqual(child.terminationStatus, SIGKILL)
            // Kernel-owned lease is released even when Swift destructors never ran.
            let lease = try ProcessLease(url: directory.appendingPathComponent("writer.lock"))
            let ledger = try ActionLedger(url: directory.appendingPathComponent("journal.json"))
            expectEqual(try ledger.previous(JournalCrashFixture.request(key: "baseline")),
                        JournalCrashFixture.result(key: "baseline"))
            if phase == "completion" && name == "directory-sync" {
                expectEqual(try ledger.previous(JournalCrashFixture.request()), JournalCrashFixture.result())
            } else if phase == "completion" || name == "directory-sync" {
                expectThrows(try ledger.previous(JournalCrashFixture.request())) {
                    expectEqual($0 as? HarnessError, .effectUnknown)
                }
            } else {
                expectEqual(try ledger.previous(JournalCrashFixture.request()), nil)
            }
            let leftovers = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasPrefix(".journal-") }
            expectEqual(leftovers.count, name == "directory-sync" ? 0 : 1)
            for file in leftovers {
                let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                expectEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
                let bytes = try Data(contentsOf: file)
                expectFalse(String(decoding: bytes, as: UTF8.self).contains("crash-fixture-private-text"))
            }
            // Reopening never promotes or deletes orphaned temporary records.
            _ = try ActionLedger(url: directory.appendingPathComponent("journal.json"))
            expectEqual(try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasPrefix(".journal-") }.count, leftovers.count)
            withExtendedLifetime(lease) {}
        }
    }
    func testAbruptExitDuringIntent() async throws { try await runMatrix(phase: "intent") }
    func testAbruptExitDuringCompletion() async throws { try await runMatrix(phase: "completion") }
}
