// ConnectionSession - Manages an active TV connection
// Thread-safe connection state management using Actor isolation

import Foundation

// NOTE: We store a reference to the higher-level WebSocketClient abstraction instead of the raw
// URLSessionWebSocketTask. This aligns the session with the TVClient implementation which manages
// connection lifecycle via WebSocketClient. On platforms where WebSocket functionality is stubbed
// (e.g. FoundationNetworking environments), WebSocketClient still exists as a stub actor so this
// unified type works cross-platform.

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
    
    /// Active WebSocket abstraction (nil when disconnected)
    public private(set) var webSocketClient: WebSocketClient?
    
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
    self.webSocketClient = nil
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
    
    /// Associate an active WebSocketClient with this session
    /// - Parameter client: Connected WebSocketClient instance
    public func setWebSocket(_ client: WebSocketClient) {
        webSocketClient = client
    }
    
    /// Update last activity timestamp
    public func updateActivity() {
        lastActivity = Date()
    }
    
    /// Clear WebSocket connection
    public func clearWebSocket() {
        webSocketClient = nil
        connectedAt = nil
    }

    /// Retrieve the active WebSocket client, if connected
    /// - Returns: Active WebSocketClient or nil when disconnected
    public func webSocket() -> WebSocketClient? {
        webSocketClient
    }
}
