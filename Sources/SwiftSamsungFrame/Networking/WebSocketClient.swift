// WebSocketClient - Manages WebSocket connection to Samsung TV
// Actor-based thread-safe WebSocket communication

import Foundation

#if canImport(FoundationNetworking)
// Linux stub - WebSocket not fully supported
public actor WebSocketClient {
    public init() {}
    
    public func connect(to url: URL) async throws {
        throw TVError.connectionFailed(reason: "WebSocket not supported on this platform")
    }
    
    public func disconnect() async {}
    
    public func send(_ message: Data) async throws {}
    
    public func receive() async throws -> Data {
        throw TVError.connectionFailed(reason: "WebSocket not supported on this platform")
    }
}
#else
/// Manages WebSocket connection to Samsung TV using URLSessionWebSocketTask
public actor WebSocketClient {
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var isConnected = false
    private var receiveTask: Task<Void, Never>?
    private var messageHandler: ((Data) -> Void)?
    
    /// Initialize WebSocket client
    public init() {}
    
    /// Connect to WebSocket URL
    /// - Parameter url: WebSocket URL (wss://host:port/api/v2/channels/samsung.remote.control)
    /// - Throws: TVError if connection fails
    public func connect(to url: URL) async throws {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true
        
        // Trust self-signed certificates for Samsung TVs
        let delegate = WebSocketDelegate()
        session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        
        guard let session else {
            throw TVError.connectionFailed(reason: "Failed to create URL session")
        }
        
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        
        // Start receiving messages
        startReceiving()
    }
    
    /// Disconnect from WebSocket
    public func disconnect() async {
        receiveTask?.cancel()
        receiveTask = nil
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
        isConnected = false
    }
    
    /// Send message to TV
    /// - Parameter message: Message data to send
    /// - Throws: TVError if send fails
    public func send(_ message: Data) async throws {
        guard let webSocketTask, isConnected else {
            throw TVError.connectionFailed(reason: "WebSocket not connected")
        }
        
        let textMessage = String(data: message, encoding: .utf8) ?? ""
        try await webSocketTask.send(.string(textMessage))
    }
    
    /// Send JSON-encoded message
    /// - Parameter message: Encodable message to send
    /// - Throws: TVError if encoding or send fails
    public func sendJSON<T: Encodable>(_ message: T) async throws {
        let data = try JSONEncoder().encode(message)
        try await send(data)
    }
    
    /// Set message handler for received messages
    /// - Parameter handler: Closure to handle incoming messages
    public func setMessageHandler(_ handler: @escaping (Data) -> Void) {
        messageHandler = handler
    }
    
    /// Check if connected
    public var connected: Bool {
        isConnected
    }
    
    // MARK: - Private Methods
    
    private func startReceiving() {
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    guard let self, let webSocketTask else { break }
                    
                    let message = try await webSocketTask.receive()
                    
                    switch message {
                    case .string(let text):
                        if let data = text.data(using: .utf8) {
                            await self.handleMessage(data)
                        }
                    case .data(let data):
                        await self.handleMessage(data)
                    @unknown default:
                        break
                    }
                } catch {
                    // Connection closed or error occurred
                    await self?.disconnect()
                    break
                }
            }
        }
    }
    
    private func handleMessage(_ data: Data) {
        messageHandler?(data)
    }
}

/// URLSession delegate to handle TLS certificate validation
private class WebSocketDelegate: NSObject, URLSessionWebSocketDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Trust self-signed certificates from Samsung TVs
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
#endif
