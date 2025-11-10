import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(os)
import os
#endif

/// WebSocket client for Samsung TV communication
public actor WebSocketClient {
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    private var isConnected = false
    private var pingTimer: Task<Void, Never>?
    
    /// Callback for received messages
    private var onMessage: (@Sendable (Data) async -> Void)?
    
    /// Callback for connection state changes
    private var onStateChange: (@Sendable (Bool) async -> Void)?
    
    /// Creates a new WebSocket client
    public init() {
        // Configure session to accept self-signed certificates
        let configuration = URLSessionConfiguration.default
        self.urlSession = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
    }
    
    /// Sets the message callback
    /// - Parameter callback: Callback for received messages
    public func setMessageCallback(_ callback: (@Sendable (Data) async -> Void)?) {
        onMessage = callback
    }
    
    /// Sets the state change callback
    /// - Parameter callback: Callback for connection state changes
    public func setStateChangeCallback(_ callback: (@Sendable (Bool) async -> Void)?) {
        onStateChange = callback
    }
    
    /// Connects to a WebSocket URL
    /// - Parameter url: WebSocket URL
    public func connect(to url: URL) async throws {
        #if canImport(os)
        Logger.networking.info("Connecting to WebSocket: \(url.absoluteString)")
        #endif
        
        // Create WebSocket task with delegate for certificate handling
        let request = URLRequest(url: url)
        let task = urlSession.webSocketTask(with: request)
        
        webSocketTask = task
        task.resume()
        
        isConnected = true
        await onStateChange?(true)
        
        // Start receiving messages
        await startReceiving()
        
        // Start ping/pong health check
        startPingTimer()
    }
    
    /// Disconnects from the WebSocket
    public func disconnect() async {
        #if canImport(os)
        Logger.networking.info("Disconnecting WebSocket")
        #endif
        
        pingTimer?.cancel()
        pingTimer = nil
        
        if let task = webSocketTask {
            task.cancel(with: .goingAway, reason: nil)
        }
        
        isConnected = false
        webSocketTask = nil
        await onStateChange?(false)
    }
    
    /// Sends a message over the WebSocket
    /// - Parameter message: Message data to send
    public func send(_ message: Data) async throws {
        guard let task = webSocketTask else {
            throw TVError.notConnected
        }
        
        let textMessage = String(data: message, encoding: .utf8) ?? ""
        #if canImport(os)
        Logger.networking.debug("Sending WebSocket message: \(textMessage)")
        #endif
        
        let wsMessage = URLSessionWebSocketTask.Message.string(textMessage)
        try await task.send(wsMessage)
    }
    
    /// Sends a JSON-encodable message
    /// - Parameter message: Message to encode and send
    public func sendJSON<T: Encodable>(_ message: T) async throws {
        let data = try JSONEncoder().encode(message)
        try await send(data)
    }
    
    /// Checks if the client is connected
    public var connected: Bool {
        isConnected
    }
    
    // MARK: - Private Methods
    
    private func startReceiving() async {
        guard let task = webSocketTask else { return }
        
        do {
            let message = try await task.receive()
            
            switch message {
            case .string(let text):
                if let data = text.data(using: .utf8) {
                    await onMessage?(data)
                }
            case .data(let data):
                await onMessage?(data)
            @unknown default:
                break
            }
            
            // Continue receiving
            if isConnected {
                await startReceiving()
            }
        } catch {
            #if canImport(os)
            Logger.networking.error("WebSocket receive error: \(error.localizedDescription)")
            #endif
            
            if isConnected {
                isConnected = false
                await onStateChange?(false)
            }
        }
    }
    
    private func startPingTimer() {
        pingTimer?.cancel()
        
        pingTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                
                guard let self = self, !Task.isCancelled else { break }
                
                await self.sendPing()
            }
        }
    }
    
    private func sendPing() async {
        guard let task = webSocketTask else { return }
        
        do {
            try await task.sendPing()
            #if canImport(os)
            Logger.networking.debug("WebSocket ping sent")
            #endif
        } catch {
            #if canImport(os)
            Logger.networking.error("WebSocket ping failed: \(error.localizedDescription)")
            #endif
        }
    }
}
