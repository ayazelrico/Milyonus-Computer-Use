import Foundation
import Darwin
import ComputerUseContracts

/// All harness instances in this login share an advisory lock. This coordinates cooperating
/// instances, not arbitrary same-user malware; it is not an authentication boundary.
public final class ProcessLease {
    private var descriptor: Int32 = -1
    public init(url: URL) throws {
        try PrivateFile.validateDirectory(url.deletingLastPathComponent())
        let fd = Darwin.open(url.path, O_CREAT | O_RDWR | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw HarnessError.persistenceFailed }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == getuid(), info.st_mode & S_IFMT == S_IFREG,
              info.st_mode & 0o077 == 0, info.st_nlink == 1 else {
            Darwin.close(fd); throw HarnessError.unauthorized
        }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { Darwin.close(fd); throw HarnessError.leaseBusy }
        descriptor = fd
    }
    deinit { if descriptor >= 0 { flock(descriptor, LOCK_UN); Darwin.close(descriptor) } }
}
