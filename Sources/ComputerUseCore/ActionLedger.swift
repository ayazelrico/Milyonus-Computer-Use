import Foundation
import CryptoKit
import ComputerUseContracts

public enum ExecutionMethod: String { case semantic, nativeText, nativeClick, nativeScroll, nativeDrag }

/// No request text is persisted. A previous unresolved intent must never be replayed.
public final class ActionLedger {
    private struct Entry: Codable {
        var key: String
        var fingerprint: String
        var result: ActionResult?
    }
    private struct Document: Codable { var version: Int; var entries: [Entry] }
    private var entries: [String: Entry] = [:]
    // A failed durability barrier may leave disk and memory different. Reopen before any further write.
    private var persistenceFaulted = false
    private let url: URL
    private let writeCheckpoint: ((JournalWriteStage) throws -> Void)?
    public convenience init(url: URL) throws {
        try self.init(url: url, writeCheckpoint: nil)
    }
    // No environment variable, CLI option or RPC exposes fault injection.
    package init(url: URL, writeCheckpoint: ((JournalWriteStage) throws -> Void)?) throws {
        self.url = url
        self.writeCheckpoint = writeCheckpoint
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                               attributes: [.posixPermissions: 0o700])
        try PrivateFile.validateDirectory(url.deletingLastPathComponent())
        if let data = try PrivateFile.read(url, maximumBytes: 2_000_000) {
            let document = try JSONDecoder().decode(Document.self, from: data)
            guard document.version == 1 else { throw HarnessError.protocolMismatch }
            let values = document.entries
            guard values.count <= 2000, Set(values.map(\.key)).count == values.count,
                  values.allSatisfy(Self.isValidEntry) else { throw HarnessError.persistenceFailed }
            entries = Dictionary(uniqueKeysWithValues: values.map { ($0.key, $0) })
        }
    }
    private static func isIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128 && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || [45, 46, 95].contains($0)
        }
    }
    private static func isValidEntry(_ entry: Entry) -> Bool {
        guard isIdentifier(entry.key), entry.fingerprint.utf8.count == 64,
              entry.fingerprint.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { return false }
        guard let result = entry.result else { return true }
        return (try? result.validate()) != nil
    }
    private func fingerprint(_ request: ActionRequest, method: ExecutionMethod) throws -> String {
        var normalized = request
        normalized.requestId = "canonical"
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var data = try encoder.encode(normalized)
        // Preserve semantic v1 fingerprints; distinguish native input from AX writes.
        if method != .semantic { data.insert(contentsOf: Array((method.rawValue + "\0").utf8), at: 0) }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    public func previous(_ request: ActionRequest, method: ExecutionMethod = .semantic) throws -> ActionResult? {
        try request.validate()
        guard let entry = entries[request.idempotencyKey] else { return nil }
        guard entry.fingerprint == (try fingerprint(request, method: method)) else { throw HarnessError.idempotencyConflict }
        guard var result = entry.result else { throw HarnessError.effectUnknown }
        result.requestId = request.requestId
        return result
    }
    public func begin(_ request: ActionRequest, method: ExecutionMethod = .semantic) throws {
        try request.validate()
        guard !persistenceFaulted else { throw HarnessError.persistenceFailed }
        guard entries.count < 2000 else { throw HarnessError.resourceLimit }
        guard entries[request.idempotencyKey] == nil else { throw HarnessError.idempotencyConflict }
        let entry = Entry(key: request.idempotencyKey, fingerprint: try fingerprint(request, method: method))
        entries[entry.key] = entry
        do { try persist() } catch {
            persistenceFaulted = true
            entries.removeValue(forKey: entry.key)
            throw HarnessError.persistenceFailed
        }
    }
    public func finish(_ request: ActionRequest, result: ActionResult, method: ExecutionMethod = .semantic) throws {
        try request.validate()
        guard !persistenceFaulted else { throw HarnessError.effectUnknown }
        guard var entry = entries[request.idempotencyKey] else { throw HarnessError.persistenceFailed }
        guard entry.fingerprint == (try fingerprint(request, method: method)) else { throw HarnessError.idempotencyConflict }
        try result.validate()
        guard result.requestId == request.requestId else { throw HarnessError.protocolMismatch }
        // Completion is immutable, including unknown effects. Exact repeated completion is harmless.
        if let completed = entry.result {
            guard completed == result else { throw HarnessError.idempotencyConflict }
            return
        }
        entry.result = result
        entries[entry.key] = entry
        do { try persist() } catch {
            persistenceFaulted = true
            entry.result = nil; entries[entry.key] = entry
            throw HarnessError.effectUnknown
        }
    }
    private func persist() throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(Document(version: 1, entries: entries.values.sorted { $0.key < $1.key }))
        guard data.count <= 2_000_000 else { throw HarnessError.resourceLimit }
        try PrivateFile.write(data, to: url, checkpoint: writeCheckpoint)
    }
}
