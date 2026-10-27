import Foundation

extension Observation {
    /// Structural admission only. Freshness, session scope and native target
    /// resolution remain separate checks at their respective boundaries.
    public func validate() throws {
        func identifier(_ value: String) -> Bool {
            !value.isEmpty && value.utf8.count <= 128 && value.utf8.allSatisfy {
                (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
                    || [45, 46, 95].contains($0)
            }
        }
        guard identifier(id), identifier(sessionId), !bundleId.isEmpty,
              bundleId.utf8.count <= 255, !bundleId.contains("\0"), pid > 0,
              capturedAt.timeIntervalSinceReferenceDate.isFinite,
              source == "accessibility", elements.count <= 300 else { throw HarnessError.protocolMismatch }
        var seen = Set<String>()
        var textBytes = 0
        for element in elements {
            guard identifier(element.id), seen.insert(element.id).inserted,
                  !element.role.isEmpty, element.bounds?.isValid != false,
                  element.actions.count <= ActionKind.allCases.count,
                  Set(element.actions).count == element.actions.count else { throw HarnessError.protocolMismatch }
            for text in [Optional(element.role), element.identifier, element.label, element.value] {
                guard let text else { continue }
                let count = text.utf8.count
                guard count < 48_000 - textBytes else { throw HarnessError.protocolMismatch }
                textBytes += count
            }
        }
    }
}
