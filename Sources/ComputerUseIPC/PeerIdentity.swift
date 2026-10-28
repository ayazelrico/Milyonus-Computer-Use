import Foundation
import Security

public enum BrokerConnectionError: Error, Equatable, Sendable {
    case invalidIdentity, invalidService, alreadyConnected, authenticationFailed, protocolMismatch, timeout, cancelled, unauthorized, resourceLimit, requestFailed
}

/// Trusted host configuration only. Never construct from a remote message or an observation.
public struct BrokerPeerIdentity: Sendable {
    public let requirement: String
    public let isDevelopmentPin: Bool

    /// Requires Apple-issued Developer ID Application code, the exact team, and signing identifier.
    public init(teamID: String, signingIdentifier: String) throws {
        guard teamID.utf8.count == 10,
              teamID.utf8.allSatisfy({ (65...90).contains($0) || (48...57).contains($0) }),
              Self.validIdentifier(signingIdentifier) else { throw BrokerConnectionError.invalidIdentity }
        let expression = "anchor apple generic and identifier \"\(signingIdentifier)\" "
            + "and certificate 1[field.1.2.840.113635.100.6.2.6] exists "
            + "and certificate leaf[field.1.2.840.113635.100.6.1.13] exists "
            + "and certificate leaf[subject.OU] = \"\(teamID)\""
        try Self.validate(expression)
        requirement = expression
        isDevelopmentPin = false
    }

    /// Explicit local experiment only: an exact CodeDirectory hash, not a publisher/update policy.
    public static func developmentCDHash(_ hash: String) throws -> Self {
        guard hash.utf8.count == 40, hash.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
            throw BrokerConnectionError.invalidIdentity
        }
        return try Self(developmentRequirement: "cdhash H\"\(hash)\"")
    }
    private init(developmentRequirement: String) throws {
        try Self.validate(developmentRequirement)
        requirement = developmentRequirement
        isDevelopmentPin = true
    }
    private static func validate(_ text: String) throws {
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess,
              requirement != nil else { throw BrokerConnectionError.invalidIdentity }
    }
    package static func validIdentifier(_ text: String) -> Bool {
        guard (3...255).contains(text.utf8.count) else { return false }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count >= 2 && parts.allSatisfy { part in
            !part.isEmpty && part.utf8.allSatisfy {
                (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45
            }
        }
    }
}
