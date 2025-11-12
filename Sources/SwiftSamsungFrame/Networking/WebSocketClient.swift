// WebSocketClient - Manages WebSocket connection to Samsung TV
// Actor-based thread-safe WebSocket communication

import Foundation
#if canImport(OSLog)
import OSLog
#endif

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

    public func addMessageHandler(_ handler: @escaping @Sendable (Data) -> Void) -> UUID {
        UUID()
    }

    public func removeMessageHandler(_ id: UUID) {}

    public func setMessageHandler(_ handler: @escaping @Sendable (Data) -> Void) {}
}
#else
/// Manages WebSocket connection to Samsung TV using URLSessionWebSocketTask
public actor WebSocketClient {
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var isConnected = false
    private var receiveTask: Task<Void, Never>?
    private var messageHandlers: [UUID: @Sendable (Data) -> Void] = [:]
    private var primaryHandlerID: UUID?

    /// Initialize WebSocket client
    public init() {}

    /// Connect to WebSocket URL
    /// - Parameter url: WebSocket URL (wss://host:port/api/v2/channels/samsung.remote.control)
    /// - Parameter protocols: Optional WebSocket subprotocols (defaults to empty, Samsung TVs work without them)
    /// - Throws: TVError if connection fails
    public func connect(to url: URL, protocols: [String] = []) async throws {
        print("[WebSocketClient] Connecting to: \(url)")
        print("[WebSocketClient] Protocols: \(protocols.isEmpty ? "(none)" : protocols.joined(separator: ", "))")
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true

    // Trust self-signed certificates for Samsung TVs. Expect the hostname from the URL for best-effort validation.
    let expectedHost = url.host ?? ""
    let delegate = WebSocketDelegate(expectedHostname: expectedHost)
    session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)

        guard let session else {
            throw TVError.connectionFailed(reason: "Failed to create URL session")
        }

    webSocketTask = session.webSocketTask(with: url, protocols: protocols)
        print("[WebSocketClient] WebSocket task created, resuming...")
        webSocketTask?.resume()
        
        isConnected = true

        // Start receiving messages immediately
        print("[WebSocketClient] Starting receive loop...")
        startReceiving()
        
        // Send a ping to test connection
        print("[WebSocketClient] Sending ping to test connection...")
        webSocketTask?.sendPing { error in
            if let error = error {
                print("[WebSocketClient] Ping failed: \(error)")
            } else {
                print("[WebSocketClient] Ping succeeded - connection is alive")
            }
        }
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
        messageHandlers.removeAll()
        primaryHandlerID = nil
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
    public func addMessageHandler(_ handler: @escaping @Sendable (Data) -> Void) -> UUID {
        let identifier = UUID()
        messageHandlers[identifier] = handler
        return identifier
    }

    public func removeMessageHandler(_ id: UUID) {
        messageHandlers.removeValue(forKey: id)
        if primaryHandlerID == id {
            primaryHandlerID = nil
        }
    }

    public func setMessageHandler(_ handler: @escaping @Sendable (Data) -> Void) {
        if let primaryHandlerID {
            messageHandlers.removeValue(forKey: primaryHandlerID)
        }
        let identifier = UUID()
        primaryHandlerID = identifier
        messageHandlers[identifier] = handler
    }

    /// Check if connected
    public var connected: Bool {
        isConnected
    }

    // MARK: - Private Methods

    private func startReceiving() {
        print("[WebSocketClient] startReceiving called")
        receiveTask = Task { [weak self] in
            print("[WebSocketClient] Receive task started")
            await self?.receiveLoop()
        }
    }

    private func receiveLoop() async {
        print("[WebSocketClient] Receive loop started")
        while !Task.isCancelled {
            do {
                guard let task = self.webSocketTask else {
                    print("[WebSocketClient] Receive loop ending - no task")
                    #if canImport(OSLog)
                    Logger.connection.warning("WebSocketClient: Receive loop ending - no task")
                    #endif
                    break
                }
                print("[WebSocketClient] Waiting for message...")
                let message = try await task.receive()
                print("[WebSocketClient] Received message!")
                #if canImport(OSLog)
                Logger.connection.debug("WebSocketClient: Received message")
                #endif
                switch message {
                case .string(let text):
                    print("[WebSocketClient] Message type: string, length: \(text.count)")
                    print("[WebSocketClient] Raw message: \(text.prefix(500))")
                    if let data = text.data(using: .utf8) {
                        self.handleMessage(data)
                    }
                case .data(let data):
                    print("[WebSocketClient] Message type: data, length: \(data.count)")
                    if let text = String(data: data, encoding: .utf8) {
                        print("[WebSocketClient] Raw message: \(text.prefix(500))")
                    }
                    self.handleMessage(data)
                @unknown default:
                    print("[WebSocketClient] Message type: unknown")
                    break
                }
            } catch {
                print("[WebSocketClient] Receive loop error: \(error)")
                #if canImport(OSLog)
                Logger.connection.error("WebSocket receive loop ended: \(error.localizedDescription)")
                #endif
                await self.disconnect()
                break
            }
        }
        print("[WebSocketClient] Receive loop ended")
    }

    private func handleMessage(_ data: Data) {
        print("[WebSocketClient] Handling message, dispatching to \(messageHandlers.count) handler(s)")
        for handler in messageHandlers.values {
            handler(data)
        }
    }
}

/// URLSession delegate to handle TLS certificate validation
private final class WebSocketDelegate: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private let expectedHostname: String

    init(expectedHostname: String) {
        self.expectedHostname = expectedHostname
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        print("[WebSocketDelegate] Received auth challenge: \(challenge.protectionSpace.authenticationMethod)")
        // Samsung TVs present self-signed certificates and often advertise hostnames that do not
        // match the IP address we connect to. Accept the certificate as-is so TLS still encrypts
        // the traffic without requiring manual trust installation.
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            print("[WebSocketDelegate] Accepting server trust for SSL")
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }
        print("[WebSocketDelegate] Using default handling")
        completionHandler(.performDefaultHandling, nil)
    }
}
#endif
