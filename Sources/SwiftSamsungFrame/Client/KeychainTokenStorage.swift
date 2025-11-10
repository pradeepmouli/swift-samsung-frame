import Foundation

/// Default implementation of TokenStorageProtocol using Keychain
public actor KeychainTokenStorage: TokenStorageProtocol {
    /// Shared instance
    public static let shared = KeychainTokenStorage()
    
    /// Private initializer for singleton
    private init() {}
    
    /// Saves an authentication token
    /// - Parameters:
    ///   - token: Token to save
    ///   - deviceId: Device ID
    /// - Returns: True if successful
    public func saveToken(_ token: AuthenticationToken, for deviceId: String) async -> Bool {
        return token.saveToKeychain()
    }
    
    /// Loads an authentication token
    /// - Parameter deviceId: Device ID
    /// - Returns: Token if found
    public func loadToken(for deviceId: String) async -> AuthenticationToken? {
        return AuthenticationToken.loadFromKeychain(deviceId: deviceId)
    }
    
    /// Deletes an authentication token
    /// - Parameter deviceId: Device ID
    /// - Returns: True if successful
    public func deleteToken(for deviceId: String) async -> Bool {
        return AuthenticationToken.deleteFromKeychain(deviceId: deviceId)
    }
}
