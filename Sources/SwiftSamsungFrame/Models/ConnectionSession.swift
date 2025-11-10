import Foundation

/// Represents an active connection session to a TV
public actor ConnectionSession {
    /// Current connection state
    public private(set) var state: ConnectionState
    
    /// Authentication token for this session
    public private(set) var token: AuthenticationToken?
    
    /// TV device for this session
    public let device: TVDevice
    
    /// Timestamp when the session was established
    public private(set) var connectedAt: Date?
    
    /// Timestamp of last successful communication
    public private(set) var lastActivityAt: Date?
    
    /// Creates a new connection session
    /// - Parameters:
    ///   - device: TV device
    ///   - state: Initial state (default: disconnected)
    public init(device: TVDevice, state: ConnectionState = .disconnected) {
        self.device = device
        self.state = state
    }
    
    /// Updates the connection state
    /// - Parameter newState: New connection state
    public func updateState(_ newState: ConnectionState) {
        state = newState
        if newState == .connected || newState == .authenticated {
            if connectedAt == nil {
                connectedAt = Date()
            }
            lastActivityAt = Date()
        } else if newState == .disconnected || newState == .failed {
            connectedAt = nil
        }
    }
    
    /// Sets the authentication token
    /// - Parameter token: Authentication token
    public func setToken(_ token: AuthenticationToken) {
        self.token = token
    }
    
    /// Clears the authentication token
    public func clearToken() {
        token = nil
    }
    
    /// Records activity on this session
    public func recordActivity() {
        lastActivityAt = Date()
    }
    
    /// Checks if the session is active
    public var isActive: Bool {
        state == .connected || state == .authenticated
    }
    
    /// Duration of the current session
    public var sessionDuration: TimeInterval? {
        guard let connectedAt = connectedAt else { return nil }
        return Date().timeIntervalSince(connectedAt)
    }
}
