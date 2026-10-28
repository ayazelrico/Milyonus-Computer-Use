import Foundation
import Darwin

/// Explicit test-only receiver evidence. Never records key/text input or unrelated windows.
@MainActor
final class FixtureEventTrace {
    static let shared = FixtureEventTrace()
    private var descriptor: Int32 = -1
    private var remaining = 64
    private init() {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--event-trace"), index + 1 < args.count else { return }
        let path = URL(fileURLWithPath: args[index + 1]).standardizedFileURL
        let parent = path.deletingLastPathComponent()
        let temporary = FileManager.default.temporaryDirectory
        var expectedRoot = stat(), actualRoot = stat()
        guard stat(temporary.path, &expectedRoot) == 0,
              stat(parent.deletingLastPathComponent().path, &actualRoot) == 0,
              expectedRoot.st_dev == actualRoot.st_dev, expectedRoot.st_ino == actualRoot.st_ino else { return }
        guard path.lastPathComponent == "events.ndjson",
              parent.lastPathComponent.hasPrefix("milyonus-companion-xpc-") else { return }
        var info = stat()
        guard lstat(parent.path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR,
              info.st_uid == getuid(), info.st_mode & 0o777 == 0o700 else { return }
        descriptor = open(path.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
    }
    func record(_ event: String) {
        guard descriptor >= 0, remaining > 0, ["down", "drag", "up"].contains(event) else { return }
        remaining -= 1
        guard let data = try? JSONSerialization.data(withJSONObject: ["event": event,
            "uptime": ProcessInfo.processInfo.systemUptime], options: [.sortedKeys]) else { return }
        let line = data + Data([10])
        let written = line.withUnsafeBytes { Darwin.write(descriptor, $0.baseAddress, $0.count) }
        if written != line.count { Darwin.close(descriptor); descriptor = -1 }
    }
    isolated deinit { if descriptor >= 0 { Darwin.close(descriptor) } }
}
