// TVError - Error types for Samsung TV Client Library
// Comprehensive error handling for all TV operations

import Foundation

/// Errors that can occur during TV operations
public enum TVError: Error, Sendable {
    /// Connection to TV failed
    case connectionFailed(reason: String)
    
    /// TV requires authentication/pairing
    case authenticationRequired
    
    /// Authentication failed or was rejected
    case authenticationFailed
    
    /// Operation timed out
    case timeout(operation: String)
    
    /// Network is unreachable
    case networkUnreachable
    
    /// Invalid or unexpected response from TV
    case invalidResponse(details: String)
    
    /// Command execution failed
    case commandFailed(code: Int, message: String)
    
    /// Art Mode is not supported on this TV
    case artModeNotSupported
    
    /// Invalid image format for upload
    case invalidImageFormat(expected: ImageType)
    
    /// Image upload failed
    case uploadFailed(reason: String)
    
    /// Device not found
    case deviceNotFound(id: String)
    
    /// Authentication token has expired
    case tokenExpired
    
    /// API version not supported
    case unsupportedAPIVersion(APIVersion)
}

extension TVError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .authenticationRequired:
            return "Authentication required. Please approve the connection on your TV."
        case .authenticationFailed:
            return "Authentication failed. The connection was rejected."
        case .timeout(let operation):
            return "Operation timed out: \(operation)"
        case .networkUnreachable:
            return "Network is unreachable. Please check your connection."
        case .invalidResponse(let details):
            return "Invalid response from TV: \(details)"
        case .commandFailed(let code, let message):
            return "Command failed (code \(code)): \(message)"
        case .artModeNotSupported:
            return "Art Mode is not supported on this TV model."
        case .invalidImageFormat(let expected):
            return "Invalid image format. Expected: \(expected.rawValue)"
        case .uploadFailed(let reason):
            return "Upload failed: \(reason)"
        case .deviceNotFound(let id):
            return "Device not found: \(id)"
        case .tokenExpired:
            return "Authentication token has expired. Please reconnect."
        case .unsupportedAPIVersion(let version):
            return "Unsupported API version: \(version.rawValue)"
        }
    }
}
