import AppKit
import Darwin

/// Explicit one-shot hostile-AX fixture. Only fixed event names and monotonic
/// times are recorded; no field values, keys, screenshots or user windows.
@MainActor
final class FixtureAXStall {
    static let shared = FixtureAXStall()
    private var descriptor: Int32 = -1
    private var signalSource: DispatchSourceSignal?
    private var armed = false
    private var consumed = false
    private var remaining = 4
    var available: Bool { descriptor >= 0 }

    private init() {
        let args = CommandLine.arguments
        guard args.contains("--ax-stall-on-signal"),
              !args.contains("--close-on-test-signal"), !args.contains("--hide-on-test-signal"),
              let index = args.firstIndex(of: "--ax-stall-trace"), index + 1 < args.count else { return }
        let path = URL(fileURLWithPath: args[index + 1]).standardizedFileURL
        let parent = path.deletingLastPathComponent()
        guard path.lastPathComponent == "ax-stall.ndjson",
              parent.lastPathComponent.hasPrefix("milyonus-isolated-read-") else { return }
        var expectedRoot = stat(), actualRoot = stat(), before = stat(), opened = stat()
        guard stat(FileManager.default.temporaryDirectory.path, &expectedRoot) == 0,
              stat(parent.deletingLastPathComponent().path, &actualRoot) == 0,
              expectedRoot.st_dev == actualRoot.st_dev, expectedRoot.st_ino == actualRoot.st_ino,
              lstat(parent.path, &before) == 0, before.st_mode & S_IFMT == S_IFDIR,
              before.st_uid == getuid(), before.st_mode & 0o777 == 0o700 else { return }
        let directory = open(parent.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard directory >= 0 else { return }
        defer { Darwin.close(directory) }
        guard fstat(directory, &opened) == 0, opened.st_dev == before.st_dev,
              opened.st_ino == before.st_ino, opened.st_uid == getuid(), opened.st_mode & 0o777 == 0o700 else { return }
        descriptor = openat(directory, "ax-stall.ndjson", O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        record("ready")
    }

    func install() {
        guard available else { return }
        signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.consumed, !self.armed else { return }
                self.armed = true; self.record("armed")
            }
        }
        signalSource = source; source.activate()
    }

    func beforeValueRead() {
        guard available, armed, !consumed else { return }
        consumed = true; armed = false
        record("ax-read-enter")
        // Purposeful bounded main-thread stall in the target AX server, never
        // in the broker. The operator test must observe entry before Stop.
        Thread.sleep(forTimeInterval: 5)
        record("ax-read-return")
    }

    private func record(_ event: String) {
        guard descriptor >= 0, remaining > 0,
              ["ready", "armed", "ax-read-enter", "ax-read-return"].contains(event) else { return }
        remaining -= 1
        guard let data = try? JSONSerialization.data(withJSONObject: ["event": event,
            "uptime": ProcessInfo.processInfo.systemUptime, "pid": getpid()], options: [.sortedKeys]) else { return }
        let line = data + Data([10])
        let written = line.withUnsafeBytes { Darwin.write(descriptor, $0.baseAddress, $0.count) }
        if written != line.count { Darwin.close(descriptor); descriptor = -1 }
    }

    isolated deinit { signalSource?.cancel(); if descriptor >= 0 { Darwin.close(descriptor) } }
}

@MainActor
final class FixtureAXTextField: NSTextField {
    override func accessibilityValue() -> String? {
        FixtureAXStall.shared.beforeValueRead()
        return super.accessibilityValue()
    }
}
