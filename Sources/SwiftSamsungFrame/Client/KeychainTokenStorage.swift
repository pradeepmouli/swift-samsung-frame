// KeychainTokenStorage - Secure token storage using Keychain
// Default implementation of TokenStorageProtocol

import Foundation
#if canImport(Security)
import Security

/// Secure token storage using system Keychain
public final class KeychainTokenStorage: TokenStorageProtocol, @unchecked Sendable {
    private let serviceName: String
    private let accessGroup: String?
    
    /// Initialize Keychain token storage
    /// - Parameters:
    ///   - serviceName: Service identifier for Keychain items
    ///   - accessGroup: Keychain access group for sharing (optional)
    public init(serviceName: String = "com.swiftsamsungframe.tokens", accessGroup: String? = nil) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
    }
    
    public func save(_ token: AuthenticationToken, for deviceID: String) async throws {
        let data = try JSONEncoder().encode(token)
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: deviceID,
            kSecValueData as String: data
        ]
        
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw TVError.connectionFailed(reason: "Failed to save token: \(status)")
        }
    }
    
    public func retrieve(for deviceID: String) async throws -> AuthenticationToken? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: deviceID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw TVError.connectionFailed(reason: "Failed to retrieve token: \(status)")
        }
        
        guard let data = result as? Data else {
            return nil
        }
        
        return try JSONDecoder().decode(AuthenticationToken.self, from: data)
    }
    
    public func delete(for deviceID: String) async throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: deviceID
        ]
        
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TVError.connectionFailed(reason: "Failed to delete token: \(status)")
        }
    }
    
    public func clearAll() async throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TVError.connectionFailed(reason: "Failed to clear tokens: \(status)")
        }
    }
}
#else
/// Stub implementation for platforms without Keychain support
public final class KeychainTokenStorage: TokenStorageProtocol, @unchecked Sendable {
    public init(serviceName: String = "com.swiftsamsungframe.tokens", accessGroup: String? = nil) {}
    
    public func save(_ token: AuthenticationToken, for deviceID: String) async throws {
        throw TVError.authenticationFailed(reason: "Keychain not available on this platform")
    }
    
    public func retrieve(for deviceID: String) async throws -> AuthenticationToken? {
        return nil
    }
    
    public func delete(for deviceID: String) async throws {
        // No-op
    }
    
    public func clearAll() async throws {
        // No-op
    }
}
#endif
