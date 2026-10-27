import Foundation
import Darwin
import ComputerUseContracts

/// Package-only fault checkpoints used by the standalone regression runner.
package enum JournalWriteStage: CaseIterable { case beforeFileSync, beforeRename, beforeDirectorySync }

/// Atomic replacement with private permissions from creation, not a chmod after exposure.
/// Parent directories must already belong to this user and be private.
enum PrivateFile {
    static func validateDirectory(_ directory: URL) throws {
        var info = stat()
        guard lstat(directory.path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR,
              info.st_uid == getuid(), info.st_mode & 0o077 == 0 else { throw HarnessError.persistenceFailed }
    }
    static func read(_ url: URL, maximumBytes: Int) throws -> Data? {
        let fd = open(url.path, O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC)
        if fd < 0 {
            if errno == ENOENT { return nil }
            throw HarnessError.persistenceFailed
        }
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_uid == getuid(),
              info.st_mode & 0o077 == 0, info.st_nlink == 1, info.st_size >= 0, info.st_size <= maximumBytes else { throw HarnessError.persistenceFailed }
        var result = Data(), buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count == 0 { break }
            if count < 0 { if errno == EINTR { continue }; throw HarnessError.persistenceFailed }
            guard result.count + count <= maximumBytes else { throw HarnessError.resourceLimit }
            result.append(contentsOf: buffer.prefix(count))
        }
        return result
    }
    static func write(_ data: Data, to url: URL, checkpoint: ((JournalWriteStage) throws -> Void)? = nil) throws {
        let parent = url.deletingLastPathComponent()
        try validateDirectory(parent)
        let temporary = parent.appendingPathComponent(".journal-\(UUID().uuidString).tmp")
        let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw HarnessError.persistenceFailed }
        defer { close(fd); unlink(temporary.path) }
        try data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            while offset < data.count {
                let written = Darwin.write(fd, base.advanced(by: offset), data.count - offset)
                if written < 0 && errno == EINTR { continue }
                guard written > 0 else { throw HarnessError.persistenceFailed }
                offset += written
            }
        }
        try checkpoint?(.beforeFileSync)
        guard fsync(fd) == 0 else { throw HarnessError.persistenceFailed }
        try checkpoint?(.beforeRename)
        guard rename(temporary.path, url.path) == 0 else { throw HarnessError.persistenceFailed }
        let directoryFD = open(parent.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard directoryFD >= 0 else { throw HarnessError.persistenceFailed }
        defer { close(directoryFD) }
        try checkpoint?(.beforeDirectorySync)
        guard fsync(directoryFD) == 0 else { throw HarnessError.persistenceFailed }
    }
}
