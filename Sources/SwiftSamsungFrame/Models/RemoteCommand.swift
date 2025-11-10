// RemoteCommand - Represents a remote control action
// Used to send commands to the TV

import Foundation

/// Represents a remote control action to send to the TV
public struct RemoteCommand: Sendable, Codable {
    /// The key to press
    public let keyCode: KeyCode
    
    /// Press, hold, or release
    public let type: CommandType
    
    /// When command was created
    public let timestamp: Date
    
    /// Number of times to repeat (default: 1)
    public let repeatCount: Int
    
    /// Initialize a new remote command
    /// - Parameters:
    ///   - keyCode: The key to press
    ///   - type: Command type (press, hold, release)
    ///   - timestamp: Creation timestamp
    ///   - repeatCount: Number of repetitions
    public init(
        keyCode: KeyCode,
        type: CommandType = .press,
        timestamp: Date = Date(),
        repeatCount: Int = 1
    ) {
        precondition(repeatCount >= 1, "Repeat count must be at least 1")
        self.keyCode = keyCode
        self.type = type
        self.timestamp = timestamp
        self.repeatCount = repeatCount
    }
}
