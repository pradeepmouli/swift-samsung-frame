import Foundation

/// Represents a remote control command
public struct RemoteCommand: Sendable {
    /// Key code to send
    public let keyCode: KeyCode
    
    /// Type of command (press, hold, release)
    public let type: CommandType
    
    /// Creates a new remote command
    /// - Parameters:
    ///   - keyCode: Key code
    ///   - type: Command type (default: keyPress)
    public init(keyCode: KeyCode, type: CommandType = .keyPress) {
        self.keyCode = keyCode
        self.type = type
    }
}
