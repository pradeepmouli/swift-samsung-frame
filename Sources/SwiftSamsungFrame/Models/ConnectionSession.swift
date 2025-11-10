// ConnectionSession - Manages an active TV connection
// Thread-safe connection state management using Actor isolation

import Foundation

/// Represents an active connection to a TV
public actor ConnectionSession: Identifiable {
    /// Unique session identifier
    public let id: UUID
    
    /// Connected device
    public let device: TVDevice
    
    /// Current state (disconnected, connecting, connected, error)
    public private(set) var state: ConnectionState
    
    /// Authentication token for reconnection
    public private(set) var authToken: String?
    
    #if canImport(FoundationNetworking)
    /// Active WebSocket connection
    public private(set) var websocket: Any?
    #else
    /// Active WebSocket connection
    public private(set) var websocket: URLSessionWebSocketTask?
    #endif
    
    /// Connection establishment time
    public private(set) var connectedAt: Date?
    
    /// Last communication timestamp
    public private(set) var lastActivity: Date
    
    /// Ping interval (default: 30s)
    public let healthCheckInterval: TimeInterval
    
    /// Initialize a new connection session
    /// - Parameters:
    ///   - device: TV device to connect to
    ///   - healthCheckInterval: Ping interval in seconds (default: 30)
    public init(device: TVDevice, healthCheckInterval: TimeInterval = 30) {
        self.id = UUID()
        self.device = device
        self.state = .disconnected
        self.authToken = nil
        self.websocket = nil
        self.connectedAt = nil
        self.lastActivity = Date()
        self.healthCheckInterval = healthCheckInterval
    }
    
    /// Update connection state
    /// - Parameter newState: New connection state
    public func updateState(_ newState: ConnectionState) {
        state = newState
        if newState == .connected {
            connectedAt = Date()
        }
    }
    
    /// Set authentication token
    /// - Parameter token: Authentication token string
    public func setAuthToken(_ token: String) {
        authToken = token
    }
    
    #if canImport(FoundationNetworking)
    /// Set WebSocket task
    /// - Parameter task: WebSocket task instance
    public func setWebSocket(_ task: Any) {
        websocket = task
    }
    #else
    /// Set WebSocket task
    /// - Parameter task: URLSessionWebSocketTask instance
    public func setWebSocket(_ task: URLSessionWebSocketTask) {
        websocket = task
    }
    #endif
    
    /// Update last activity timestamp
    public func updateActivity() {
        lastActivity = Date()
    }
    
    /// Clear WebSocket connection
    public func clearWebSocket() {
        websocket = nil
        connectedAt = nil
    }
}
