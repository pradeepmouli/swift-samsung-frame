import Foundation

/// Errors that can occur when interacting with Samsung TVs
public enum TVError: Error, Sendable, Equatable {
    /// Connection to the TV could not be established
    case connectionFailed(reason: String)
    
    /// Authentication with the TV failed
    case authenticationFailed(reason: String)
    
    /// The TV is not currently connected
    case notConnected
    
    /// Network is unreachable
    case networkUnreachable
    
    /// Operation timed out
    case timeout
    
    /// Command execution failed
    case commandFailed(command: String, reason: String)
    
    /// The requested operation is not supported by this TV
    case unsupportedOperation(operation: String)
    
    /// Art mode is not supported on this TV
    case artModeNotSupported
    
    /// Image upload failed
    case uploadFailed(reason: String)
    
    /// Invalid image format
    case invalidImageFormat(expected: [String], received: String)
    
    /// App not found
    case appNotFound(appId: String)
    
    /// Invalid response from TV
    case invalidResponse(details: String)
}

extension TVError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .notConnected:
            return "Not connected to TV"
        case .networkUnreachable:
            return "Network is unreachable"
        case .timeout:
            return "Operation timed out"
        case .commandFailed(let command, let reason):
            return "Command '\(command)' failed: \(reason)"
        case .unsupportedOperation(let operation):
            return "Operation '\(operation)' is not supported by this TV"
        case .artModeNotSupported:
            return "Art mode is not supported on this TV model"
        case .uploadFailed(let reason):
            return "Upload failed: \(reason)"
        case .invalidImageFormat(let expected, let received):
            return "Invalid image format. Expected: \(expected.joined(separator: ", ")), received: \(received)"
        case .appNotFound(let appId):
            return "App with ID '\(appId)' not found"
        case .invalidResponse(let details):
            return "Invalid response from TV: \(details)"
        }
    }
}
