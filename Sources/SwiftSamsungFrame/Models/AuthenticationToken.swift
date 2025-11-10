import Foundation

#if canImport(Security)
import Security
#endif

/// Authentication token for TV connections
public struct AuthenticationToken: Sendable, Codable {
    /// Token value
    public let value: String
    
    /// Token scope
    public let scope: TokenScope
    
    /// Device ID this token is for
    public let deviceId: String
    
    /// When the token was issued
    public let issuedAt: Date
    
    /// Token expiration date (if applicable)
    public let expiresAt: Date?
    
    /// Creates a new authentication token
    /// - Parameters:
    ///   - value: Token value
    ///   - scope: Token scope
    ///   - deviceId: Device ID
    ///   - issuedAt: Issued timestamp (default: now)
    ///   - expiresAt: Expiration timestamp (optional)
    public init(
        value: String,
        scope: TokenScope = .full,
        deviceId: String,
        issuedAt: Date = Date(),
        expiresAt: Date? = nil
    ) {
        self.value = value
        self.scope = scope
        self.deviceId = deviceId
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
    }
    
    /// Checks if the token is expired
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
    
    /// Checks if the token is valid
    public var isValid: Bool {
        !isExpired && !value.isEmpty
    }
}

#if canImport(Security)
// MARK: - Keychain Support
extension AuthenticationToken {
    /// Keychain service identifier
    private static let keychainService = "com.swiftsamsungframe.tokens"
    
    /// Saves the token to the Keychain
    /// - Returns: True if successful
    @discardableResult
    public func saveToKeychain() -> Bool {
        guard let data = try? JSONEncoder().encode(self) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: deviceId,
            kSecValueData as String: data
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Loads a token from the Keychain
    /// - Parameter deviceId: Device ID
    /// - Returns: Token if found
    public static func loadFromKeychain(deviceId: String) -> AuthenticationToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: deviceId,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = try? JSONDecoder().decode(AuthenticationToken.self, from: data) else {
            return nil
        }
        
        return token
    }
    
    /// Deletes a token from the Keychain
    /// - Parameter deviceId: Device ID
    /// - Returns: True if successful
    @discardableResult
    public static func deleteFromKeychain(deviceId: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: deviceId
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
#else
// MARK: - Keychain Support (Placeholder for non-Apple platforms)
extension AuthenticationToken {
    /// Saves the token to the Keychain (not available on this platform)
    /// - Returns: False (not supported)
    @discardableResult
    public func saveToKeychain() -> Bool {
        return false
    }
    
    /// Loads a token from the Keychain (not available on this platform)
    /// - Parameter deviceId: Device ID
    /// - Returns: nil (not supported)
    public static func loadFromKeychain(deviceId: String) -> AuthenticationToken? {
        return nil
    }
    
    /// Deletes a token from the Keychain (not available on this platform)
    /// - Parameter deviceId: Device ID
    /// - Returns: False (not supported)
    @discardableResult
    public static func deleteFromKeychain(deviceId: String) -> Bool {
        return false
    }
}
#endif
