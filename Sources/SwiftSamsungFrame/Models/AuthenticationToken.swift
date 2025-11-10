// AuthenticationToken - Secure token for maintaining authenticated sessions
// Stores authentication credentials securely

import Foundation

/// Represents a secure token for maintaining authenticated sessions
public struct AuthenticationToken: Sendable, Equatable, Codable {
    /// Token string (opaque)
    public let value: String
    
    /// Associated device ID
    public let deviceID: String
    
    /// When token was created
    public let issuedAt: Date
    
    /// Expiration time (if known)
    public let expiresAt: Date?
    
    /// Permitted operations
    public let scope: Set<TokenScope>
    
    /// Initialize a new authentication token
    /// - Parameters:
    ///   - value: Token string
    ///   - deviceID: Associated device identifier
    ///   - issuedAt: Creation timestamp
    ///   - expiresAt: Expiration time
    ///   - scope: Permitted operations
    public init(
        value: String,
        deviceID: String,
        issuedAt: Date = Date(),
        expiresAt: Date? = nil,
        scope: Set<TokenScope> = [.remoteControl, .appManagement, .artMode, .deviceInfo]
    ) {
        self.value = value
        self.deviceID = deviceID
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.scope = scope
    }
    
    /// Check if token has expired
    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() > expiresAt
    }
    
    /// Check if token is valid
    public var isValid: Bool {
        return !value.isEmpty && !isExpired
    }
}

// MARK: - CustomStringConvertible

extension AuthenticationToken: CustomStringConvertible {
    public var description: String {
        // Never expose the actual token value in description
        return "AuthenticationToken(deviceID: \(deviceID), issuedAt: \(issuedAt), scope: \(scope))"
    }
}
