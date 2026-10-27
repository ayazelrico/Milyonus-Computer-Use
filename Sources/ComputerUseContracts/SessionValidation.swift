import Foundation

extension Session {
    /// Validate metadata consistency, not native approval or wall-clock liveness.
    public func validate() throws {
        guard !id.isEmpty, id.utf8.count <= 128,
              id.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0)
                  || (97...122).contains($0) || [45, 46, 95].contains($0) }),
              !bundleId.isEmpty, bundleId.utf8.count <= 255, !bundleId.contains("\0"),
              generation > 0, expiresAt.timeIntervalSinceReferenceDate.isFinite,
              state == .paused || pauseReason == nil else { throw HarnessError.protocolMismatch }
    }
}
