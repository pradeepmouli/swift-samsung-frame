// TVClient - Main client for Samsung TV interaction
// Implements TVClientProtocol with connection management and control interfaces

import Foundation
#if canImport(OSLog)
import OSLog
#endif

/// Helper actor to track WebSocket handshake state
private actor HandshakeState {
    private var connectReceived = false
    private var readyReceived = false
    
    var isComplete: Bool {
        connectReceived && readyReceived
    }
    
    func markConnectReceived() {
        connectReceived = true
    }
    
    func markReadyReceived() {
        readyReceived = true
    }
}

/// Main client for Samsung TV interaction
public actor TVClient: TVClientProtocol {
    private var session: ConnectionSession?
    private var webSocketClient: WebSocketClient?
    private var restClient: RESTClient?
    private var tokenStorage: (any TokenStorageProtocol)?
    private var delegate: (any TVClientDelegate)?
    
    private let _remote: RemoteControl
    private let _apps: AppManagement
    private let _art: ArtController
    
    /// Remote control interface
    public nonisolated var remote: any RemoteControlProtocol { _remote }
    
    /// App management interface
    public nonisolated var apps: any AppManagementProtocol { _apps }
    
    /// Art mode interface  
    public nonisolated var art: any ArtControllerProtocol { _art }
    
    /// Initialize TV client
    /// - Parameter delegate: Optional delegate for state changes
    public init(delegate: (any TVClientDelegate)? = nil) {
        self.delegate = delegate
        self._remote = RemoteControl()
        self._apps = AppManagement()
        self._art = ArtController()
    }
    
    public func connect(
        to host: String,
        port: Int = 8001,
        tokenStorage: (any TokenStorageProtocol)? = nil,
        channel: WebSocketChannel = .remoteControl
    ) async throws -> ConnectionSession {
        self.tokenStorage = tokenStorage
        
        let device = TVDevice(
            id: host,
            host: host,
            port: port,
            name: "Samsung TV",
            apiVersion: .v2
        )
        
        #if canImport(OSLog)
        Logger.connection.info("Connecting to TV at \(host):\(port)")
        #endif
        
        // Create connection session
        let newSession = ConnectionSession(device: device)
        self.session = newSession
        
        // Update state to connecting
        await newSession.updateState(.connecting)
        await notifyStateChange(.connecting)
        
        let clientName = "SamsungTvArt"  // Match JavaScript client name
        let encodedClientName = Data(clientName.utf8).base64EncodedString()

        // Try to retrieve stored token prior to connection so we can include it in the URL
        var authToken: String?
        if let storage = tokenStorage {
            if let storedToken = try? await storage.retrieve(for: device.id) {
                authToken = storedToken.value
            }
        }

        // Create WebSocket URL - Samsung TVs use wss on port 8002, ws on port 8001
        let primaryScheme = port == 8002 ? "wss" : "ws"
        let fallbackScheme = primaryScheme == "wss" ? "ws" : "wss"
        let wsURL = TVClient.buildWebSocketURL(
            channel: channel,
            scheme: primaryScheme,
            host: host,
            port: port,
            base64Name: encodedClientName,
            token: authToken
        )
        let fallbackURL: URL? = fallbackScheme == primaryScheme ? nil : TVClient.buildWebSocketURL(
            channel: channel,
            scheme: fallbackScheme,
            host: host,
            port: port,
            base64Name: encodedClientName,
            token: authToken
        )

        // Initialize clients
        let wsClient = WebSocketClient()
        self.webSocketClient = wsClient
        
        let restURL = URL(string: "http://\(host):8001")!
        self.restClient = RESTClient(baseURL: restURL)
        
        do {
            // Connect WebSocket (no subprotocols - Samsung TVs work without them)
            do {
                try await wsClient.connect(to: wsURL, protocols: [])
            } catch {
                #if canImport(OSLog)
                Logger.connection.warning("WebSocket connection failed for scheme \(primaryScheme): \(error.localizedDescription)")
                #endif
                if let fallbackURL {
                    do {
                        try await wsClient.connect(to: fallbackURL, protocols: [])
                        #if canImport(OSLog)
                        Logger.connection.info("WebSocket fallback to scheme \(fallbackScheme) succeeded")
                        #endif
                    } catch {
                        throw error
                    }
                } else {
                    throw error
                }
            }
            
            // Wait for server-driven handshake (TV will send ms.channel.connect and ms.channel.ready)
            await newSession.updateState(.authenticating)
            await notifyStateChange(.authenticating)
            
            print("[TVClient] Waiting for handshake events (connect + ready)...")
            
            // Set up handshake state tracker
            let handshakeState = HandshakeState()
            
            // Set up message handler to listen for ms.channel.connect and persist tokens
            let handlerID = await wsClient.addMessageHandler { data in
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let event = json["event"] as? String else {
                    print("[TVClient] Received non-JSON or missing event message")
                    if let str = String(data: data, encoding: .utf8) {
                        print("[TVClient] Raw non-event message: \(str.prefix(200))")
                    }
                    #if canImport(OSLog)
                    Logger.connection.debug("Received non-JSON or missing event message")
                    #endif
                    return
                }
                
                print("[TVClient] Handshake: received event '\(event)'")
                if let dataField = json["data"] {
                    print("[TVClient] Event data: \(dataField)")
                }
                #if canImport(OSLog)
                Logger.connection.debug("Handshake: received event '\(event)'")
                #endif
                
                Task {
                    if event == "ms.channel.connect" {
                        print("[TVClient] ✓ Marking connect received")
                        await handshakeState.markConnectReceived()
                    } else if event == "ms.channel.ready" {
                        print("[TVClient] ✓ Marking ready received")
                        await handshakeState.markReadyReceived()
                    } else {
                        print("[TVClient] ⚠️ Received unexpected event: \(event)")
                    }
                }
            }
            
            // Also handle token persistence
            let tokenHandlerID = await wsClient.addMessageHandler { [weak self] data in
                Task { [weak self] in
                    await self?.handleConnectionMessage(data, deviceID: device.id)
                }
            }
            
            // Wait for both ms.channel.connect and ms.channel.ready events
            print("[TVClient] ⏳ Waiting for TV authorization...")
            print("[TVClient] � Please check your TV screen and APPROVE the connection request!")
            print("[TVClient] (Waiting up to 90 seconds for both connect and ready events...)")
            
            let startTime = Date()
            let timeout: TimeInterval = 90.0  // Give time for both approval and events
            while !(await handshakeState.isComplete) && Date().timeIntervalSince(startTime) < timeout {
                try await Task.sleep(for: .milliseconds(500))
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            print("[TVClient] Handshake wait completed after \(String(format: "%.2f", elapsed))s")
            
            guard await handshakeState.isComplete else {
                print("[TVClient] ❌ Handshake failed - did not receive both events")
                await wsClient.removeMessageHandler(handlerID)
                await wsClient.removeMessageHandler(tokenHandlerID)
                throw TVError.connectionFailed(reason: "Did not receive connection handshake from TV")
            }
            
            print("[TVClient] ✓ Handshake complete!")
            #if canImport(OSLog)
            Logger.connection.info("Received handshake events from TV (connect + ready)")
            #endif
            
            // Remove the connection message handlers after handshake completes
            await wsClient.removeMessageHandler(handlerID)
            await wsClient.removeMessageHandler(tokenHandlerID)
            
            await newSession.updateState(.connected)
            await newSession.setWebSocket(wsClient)
            await notifyStateChange(.connected)
            
            #if canImport(OSLog)
            Logger.connection.info("Connected successfully")
            #endif
            
            // Inject websocket into controllers
            await _remote.setWebSocket(wsClient)
            await _apps.setWebSocket(wsClient)
            await _apps.setRESTClient(restClient)
            await _art.setWebSocket(wsClient)
            await _art.setRESTClient(restClient)
            
            return newSession
        } catch {
            await newSession.updateState(.error)
            await notifyStateChange(.error)
            
            #if canImport(OSLog)
            Logger.connection.error("Connection failed: \(error.localizedDescription)")
            #endif
            
            throw TVError.connectionFailed(reason: error.localizedDescription)
        }
    }
    
    public func disconnect() async {
        guard let session else { return }
        
        #if canImport(OSLog)
        Logger.connection.info("Disconnecting from TV")
        #endif
        
        await session.updateState(.disconnecting)
        await notifyStateChange(.disconnecting)
        
        await webSocketClient?.disconnect()
    await _art.clearWebSocket()
    await session.clearWebSocket()
        
        await session.updateState(.disconnected)
        await notifyStateChange(.disconnected)
        
        self.session = nil
        self.webSocketClient = nil
        self.restClient = nil
    }
    
    public func addRESTObserver(_ observer: @escaping RESTClient.LogObserver) async -> UUID? {
        guard let restClient else { return nil }
        return restClient.addObserver(observer)
    }

    public func removeRESTObserver(_ id: UUID) async {
        restClient?.removeObserver(id)
    }

    public var state: ConnectionState {
        get async {
            await session?.state ?? .disconnected
        }
    }
    
    public func deviceInfo() async throws -> TVDevice {
        guard let session else {
            throw TVError.connectionFailed(reason: "Not connected")
        }
        
        return session.device
    }
    
    // MARK: - Private Methods
    
    private func notifyStateChange(_ state: ConnectionState) async {
        await delegate?.client(self, didChangeState: state)
    }

    /// Handle incoming WebSocket messages during connection to extract and persist tokens
    private func handleConnectionMessage(_ data: Data, deviceID: String) async {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String else {
            return
        }
        
        // Listen for ms.channel.connect event which may contain a new token
        if event == "ms.channel.connect",
           let dataDict = json["data"] as? [String: Any],
           let token = dataDict["token"] as? String,
           !token.isEmpty,
           let storage = tokenStorage {
            
            #if canImport(OSLog)
            Logger.connection.info("Received new token from TV, persisting to storage")
            #endif
            
            let authToken = AuthenticationToken(
                value: token,
                deviceID: deviceID
            )
            do {
                try await storage.save(authToken, for: deviceID)
            } catch {
                #if canImport(OSLog)
                Logger.connection.error("Failed to persist token: \(error.localizedDescription)")
                #endif
            }
        }
    }

    private static func buildWebSocketURL(
        channel: WebSocketChannel,
        scheme: String,
        host: String,
        port: Int,
        base64Name: String,
        token: String?
    ) -> URL {
        // Samsung TVs expect the base64 name parameter without URL encoding the = padding
        // Build URL manually to avoid automatic encoding
        // Always include token parameter - use "None" when no token exists (matches JS library)
        let tokenValue = token ?? "None"
        let urlString = "\(scheme)://\(host):\(port)\(channel.path)?name=\(base64Name)&token=\(tokenValue)"
        guard let url = URL(string: urlString) else {
            preconditionFailure("Failed to build WebSocket URL from: \(urlString)")
        }
        print("[TVClient] Built WebSocket URL: \(urlString)")
        return url
    }
}

// MARK: - RemoteControl Implementation

actor RemoteControl: RemoteControlProtocol {
    private var webSocket: WebSocketClient?
    private let commandTimeout: Duration = .seconds(5)
    private let retryDelay: Duration = .milliseconds(500)
    
    func setWebSocket(_ ws: WebSocketClient) {
        self.webSocket = ws
    }
    
    public func sendKey(_ key: KeyCode) async throws {
        guard let webSocket else {
            throw TVError.connectionFailed(reason: "Not connected")
        }
        
        #if canImport(OSLog)
        Logger.commands.debug("Sending key: \(key.rawValue)")
        #endif
        
        let message = WebSocketMessage.remoteControl(key: key.rawValue)
        let data = try JSONEncoder().encode(message)
        
        // Try with timeout and retry once on failure
        do {
            try await withTimeout(commandTimeout) {
                try await webSocket.send(data)
            }
        } catch is TimeoutError {
            #if canImport(OSLog)
            Logger.commands.warning("Command timed out: \(key.rawValue), retrying...")
            #endif
            
            // Retry once after delay
            try await Task.sleep(for: retryDelay)
            
            do {
                try await withTimeout(commandTimeout) {
                    try await webSocket.send(data)
                }
            } catch is TimeoutError {
                throw TVError.timeout(operation: "sendKey(\(key.rawValue))")
            } catch {
                throw TVError.commandFailed(code: -1, message: error.localizedDescription)
            }
        } catch {
            throw TVError.commandFailed(code: -1, message: error.localizedDescription)
        }
        
        #if canImport(OSLog)
        Logger.commands.debug("Key sent successfully: \(key.rawValue)")
        #endif
    }
    
    public func sendKeys(_ keys: [KeyCode], delay: Duration = .milliseconds(100)) async throws {
        #if canImport(OSLog)
        Logger.commands.info("Sending \(keys.count) keys with delay")
        #endif
        
        for (index, key) in keys.enumerated() {
            try await sendKey(key)
            
            // Don't delay after the last key
            if index < keys.count - 1 {
                try await Task.sleep(for: delay)
            }
        }
    }
    
    public func power() async throws {
        #if canImport(OSLog)
        Logger.commands.info("Toggling power")
        #endif
        
        try await sendKey(.power)
    }
    
    public func volumeUp(steps: Int = 1) async throws {
        guard steps > 0 else { return }
        
        #if canImport(OSLog)
        Logger.commands.info("Increasing volume by \(steps) steps")
        #endif
        
        for _ in 0..<steps {
            try await sendKey(.volumeUp)
            try await Task.sleep(for: .milliseconds(100))
        }
    }
    
    public func volumeDown(steps: Int = 1) async throws {
        guard steps > 0 else { return }
        
        #if canImport(OSLog)
        Logger.commands.info("Decreasing volume by \(steps) steps")
        #endif
        
        for _ in 0..<steps {
            try await sendKey(.volumeDown)
            try await Task.sleep(for: .milliseconds(100))
        }
    }
    
    public func mute() async throws {
        #if canImport(OSLog)
        Logger.commands.info("Toggling mute")
        #endif
        
        try await sendKey(.mute)
    }
    
    public func navigate(_ direction: NavigationDirection) async throws {
        #if canImport(OSLog)
        Logger.commands.debug("Navigating: \(direction)")
        #endif
        
        try await sendKey(direction.keyCode)
    }
    
    public func enter() async throws {
        #if canImport(OSLog)
        Logger.commands.debug("Pressing enter")
        #endif
        
        try await sendKey(.enter)
    }
    
    public func back() async throws {
        #if canImport(OSLog)
        Logger.commands.debug("Pressing back")
        #endif
        
        try await sendKey(.back)
    }
    
    public func home() async throws {
        #if canImport(OSLog)
        Logger.commands.info("Going to home screen")
        #endif
        
        try await sendKey(.home)
    }
}

// MARK: - AppManagement Implementation

/// Actor managing Samsung TV applications
///
/// Provides methods to list, launch, close, and manage applications on the TV.
/// Uses both WebSocket and REST API endpoints for comprehensive app control.
///
/// Example usage:
/// ```swift
/// let client = TVClient()
/// try await client.connect(to: "192.168.1.100")
///
/// // List installed apps
/// let apps = try await client.apps.list()
///
/// // Launch an app
/// try await client.apps.launch("111299000912") // YouTube
///
/// // Check app status
/// let status = try await client.apps.status(of: "111299001912")
/// ```
actor AppManagement: AppManagementProtocol {
    private var webSocket: WebSocketClient?
    private var restClient: RESTClient?
    
    func setWebSocket(_ ws: WebSocketClient) {
        self.webSocket = ws
    }
    
    func setRESTClient(_ client: RESTClient?) {
        self.restClient = client
    }
    
    /// List all installed applications on the TV
    ///
    /// Sends a WebSocket request to retrieve the list of installed apps.
    /// Note: Full response parsing requires WebSocket response handler implementation.
    ///
    /// - Returns: Array of installed TV apps (currently returns empty array pending response handler)
    /// - Throws: `TVError.connectionFailed` if not connected to TV
    ///
    /// Example:
    /// ```swift
    /// let apps = try await client.apps.list()
    /// for app in apps {
    ///     print("\(app.name) - \(app.id)")
    /// }
    /// ```
    public func list() async throws -> [TVApp] {
        guard let webSocket else {
            throw TVError.connectionFailed(reason: "Not connected")
        }
        
        #if canImport(OSLog)
        Logger.commands.debug("Requesting app list via WebSocket")
        #endif
        
        // Send app list request
        let message = AppListMessage.getAppList()
        let data = try JSONEncoder().encode(message)
        try await webSocket.send(data)
        
        // Note: In a full implementation, we would wait for and parse the response
        // For now, return empty array as this requires response handling
        return []
    }
    
    /// Launch a specific application on the TV
    ///
    /// Opens the specified app using its unique identifier. Common app IDs:
    /// - Netflix: `111299001912`
    /// - YouTube: `111299000912`
    /// - Prime Video: `3201512006785`
    ///
    /// - Parameter appID: Unique application identifier
    /// - Throws: `TVError.connectionFailed` if not connected to TV
    ///
    /// Example:
    /// ```swift
    /// try await client.apps.launch("111299001912") // Launch Netflix
    /// ```
    public func launch(_ appID: String) async throws {
        guard let webSocket else {
            throw TVError.connectionFailed(reason: "Not connected")
        }
        
        #if canImport(OSLog)
        Logger.commands.info("Launching app: \(appID)")
        #endif
        
        let message = try AppListMessage.launchApp(appID: appID)
        let data = try JSONEncoder().encode(message)
        try await webSocket.send(data)
    }
    
    /// Close a running application on the TV
    ///
    /// Terminates the specified app using the REST API. The TV will typically
    /// return to the home screen after the app is closed.
    ///
    /// - Parameter appID: Unique application identifier
    /// - Throws: `TVError.connectionFailed` if REST client not available
    /// - Throws: `TVError.commandFailed` if the TV rejects the request
    ///
    /// Example:
    /// ```swift
    /// try await client.apps.close("111299001912")
    /// ```
    public func close(_ appID: String) async throws {
        guard let restClient else {
            throw TVError.connectionFailed(reason: "REST client not available")
        }
        
        #if canImport(OSLog)
        Logger.commands.info("Closing app via REST: \(appID)")
        #endif
        
        try await restClient.closeApp(appID: appID)
    }
    
    /// Get the current status of an application
    ///
    /// Queries the TV via REST API to determine if the app is running or stopped.
    ///
    /// - Parameter appID: Unique application identifier
    /// - Returns: Current app status (`.running`, `.stopped`, or `.paused`)
    /// - Throws: `TVError.connectionFailed` if REST client not available
    /// - Throws: `TVError.invalidResponse` if response cannot be parsed
    ///
    /// Example:
    /// ```swift
    /// let status = try await client.apps.status(of: "111299001912")
    /// if status == .running {
    ///     print("App is currently running")
    /// }
    /// ```
    public func status(of appID: String) async throws -> AppStatus {
        guard let restClient else {
            throw TVError.connectionFailed(reason: "REST client not available")
        }
        
        #if canImport(OSLog)
        Logger.commands.debug("Getting app status via REST: \(appID)")
        #endif
        
        let data = try await restClient.getAppStatus(appID: appID)
        
        // Parse response to determine status
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let running = json["running"] as? Bool {
            return running ? .running : .stopped
        }
        
        return .stopped
    }
    
    /// Install an application from the TV's app store
    ///
    /// Attempts to install the specified app using the REST API.
    /// Note: This may not be supported on all TV models or for all apps.
    ///
    /// - Parameter appID: Application identifier from the TV's app store
    /// - Throws: `TVError.connectionFailed` if REST client not available
    /// - Throws: `TVError.commandFailed` if installation fails or is not supported
    ///
    /// Example:
    /// ```swift
    /// do {
    ///     try await client.apps.install("appIdFromStore")
    ///     print("App installation started")
    /// } catch {
    ///     print("Installation not supported or failed")
    /// }
    /// ```
    public func install(_ appID: String) async throws {
        guard let restClient else {
            throw TVError.connectionFailed(reason: "REST client not available")
        }
        
        #if canImport(OSLog)
        Logger.commands.info("Installing app via REST: \(appID)")
        #endif
        
        try await restClient.installApp(appID: appID)
    }
}

// MARK: - ArtController Implementation

/// Actor managing Art Mode features for Samsung Frame TVs
///
/// Provides comprehensive control over Art Mode, including:
/// - Listing and selecting artwork
/// - Uploading custom images
/// - Managing photo filters and matte styles
/// - Toggling Art Mode on/off
///
/// Note: Art Mode features are only available on Samsung Frame TV models.
/// Always check `isSupported()` before using Art Mode features.
///
/// Example usage:
/// ```swift
/// let client = TVClient()
/// try await client.connect(to: "192.168.1.100")
///
/// // Check if Art Mode is supported
/// guard try await client.art.isSupported() else {
///     print("This TV doesn't support Art Mode")
///     return
/// }
///
/// // Select an art piece
/// try await client.art.select("contentId", show: true)
///
/// // Enable Art Mode
/// try await client.art.setArtMode(enabled: true)
/// ```
actor ArtController: ArtControllerProtocol {
    private var webSocket: WebSocketClient?
    private var restClient: RESTClient?
    private var artUUID: String?
    private var cachedArtPieces: [ArtPiece] = []
    private var currentArtPiece: ArtPiece?
    private var pendingResponses: [String: [PendingContinuation]] = [:]
    private var messageHandlerToken: UUID?
    private let responseTimeout: Duration = .seconds(8)
    private let d2dClient = D2DSocketClient()
    
    private struct ArtPayload: @unchecked Sendable {
        let value: [String: Any]
    }
    
    private struct ArtResponse: @unchecked Sendable {
        let value: [String: Any]
    }

    private final class PendingContinuation: @unchecked Sendable {
        let id = UUID()
        private let lock = NSLock()
        private var isCompleted = false
        var continuation: CheckedContinuation<ArtResponse, any Error>?
        var timeoutTask: Task<Void, Never>?

        func complete(with result: Result<ArtResponse, any Error>) {
            lock.lock(); defer { lock.unlock() }
            guard !isCompleted, let continuation else { return }
            isCompleted = true
            timeoutTask?.cancel()
            continuation.resume(with: result)
            self.continuation = nil
        }
    }
    
    func setWebSocket(_ ws: WebSocketClient) async {
        if let existing = webSocket, let token = messageHandlerToken {
            await existing.removeMessageHandler(token)
            messageHandlerToken = nil
        }
        await failAllPending(with: TVError.connectionFailed(reason: "WebSocket connection replaced"))
        webSocket = ws

        let token = await ws.addMessageHandler { [weak self] data in
            guard let self else { return }
            Task { await self.handleIncomingMessage(data) }
        }
        messageHandlerToken = token
    }
    
    func setRESTClient(_ client: RESTClient?) {
        self.restClient = client
    }

    func clearWebSocket() async {
        if let webSocket, let token = messageHandlerToken {
            await webSocket.removeMessageHandler(token)
        }
        messageHandlerToken = nil
        webSocket = nil
        await failAllPending(with: TVError.connectionFailed(reason: "WebSocket disconnected"))
    }
    
    private func getOrGenerateUUID() -> String {
        if let artUUID {
            return artUUID
        }
        let uuid = UUID().uuidString
        self.artUUID = uuid
        return uuid
    }
    
    /// Send art app request via WebSocket
    private func sendArtRequest(_ request: [String: Any]) async throws {
        guard let webSocket else {
            throw TVError.connectionFailed(reason: "Not connected")
        }
        
        var requestData = request
        requestData["id"] = getOrGenerateUUID()
        
        let message = try ArtChannelMessage.artAppRequest(requestData)
        let data = try JSONEncoder().encode(message)
        try await webSocket.send(data)
    }
    
    /// Check if Art Mode is supported on the connected TV
    ///
    /// Queries the TV's device information to determine if it's a Frame TV
    /// with Art Mode capabilities.
    ///
    /// - Returns: `true` if Art Mode is supported, `false` otherwise
    /// - Throws: `TVError.connectionFailed` if REST client not available
    /// - Throws: `TVError.networkUnreachable` if unable to reach TV
    ///
    /// Example:
    /// ```swift
    /// if try await client.art.isSupported() {
    ///     print("Art Mode is available")
    /// } else {
    ///     print("This TV doesn't support Art Mode")
    /// }
    /// ```
    public func isSupported() async throws -> Bool {
        guard let restClient else {
            throw TVError.connectionFailed(reason: "REST client not available")
        }
        
        // Check device info for Frame TV support
        let data = try await restClient.getDeviceInfo()
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let device = json["device"] as? [String: Any],
           let frameSupport = device["FrameTVSupport"] as? String {
            return frameSupport == "true"
        }
        
        return false
    }
    
    /// List all available art pieces on the TV
    ///
    /// Retrieves the list of art available in the TV's art library,
    /// including both built-in artwork and user-uploaded images.
    ///
    /// - Returns: Array of art pieces (currently returns empty array pending WebSocket response handler)
    /// - Throws: `TVError.connectionFailed` if not connected
    /// - Throws: `TVError.artModeNotSupported` if TV doesn't support Art Mode
    ///
    /// Note: Full implementation requires WebSocket response handling.
    ///
    /// Example:
    /// ```swift
    /// let artPieces = try await client.art.listAvailable()
    /// for art in artPieces {
    ///     print("\(art.title) - \(art.id)")
    /// }
    /// ```
    public func listAvailable() async throws -> [ArtPiece] {
        #if canImport(OSLog)
        Logger.commands.debug("Requesting art list")
        #endif
        
        let response = try await performArtRequest(
            "get_content_list",
            additionalData: [
                "category": NSNull()
            ]
        )
        
        let contentList = coerceArrayOfDictionaries(
            response["content_list"] ?? response["art_list"]
        ) ?? []
        let pieces = contentList.compactMap { parseArtPiece(from: $0) }
        cachedArtPieces = pieces
        return pieces
    }
    
    /// Get the currently displayed art piece
    ///
    /// Retrieves information about the art currently shown on the TV.
    ///
    /// - Returns: Current art piece
    /// - Throws: `TVError.artModeNotSupported` if TV doesn't support Art Mode
    /// - Throws: `TVError.connectionFailed` if not connected
    ///
    /// Note: Full implementation requires WebSocket response handling.
    ///
    /// Example:
    /// ```swift
    /// let current = try await client.art.current()
    /// print("Currently displaying: \(current.title)")
    /// ```
    public func current() async throws -> ArtPiece {
        #if canImport(OSLog)
        Logger.commands.debug("Requesting current artwork")
        #endif
        
        let response = try await performArtRequest("get_current_artwork")
        let piece = parseArtPiece(from: response)
            ?? coerceArrayOfDictionaries(response["content_list"])?.compactMap { parseArtPiece(from: $0) }.first
        guard let art = piece else {
            throw TVError.invalidResponse(details: "Missing current art payload")
        }
        currentArtPiece = art
        if let index = cachedArtPieces.firstIndex(where: { $0.id == art.id }) {
            cachedArtPieces[index] = art
        } else {
            cachedArtPieces.append(art)
        }
        return art
    }
    
    /// Select an art piece to display
    ///
    /// Changes the displayed artwork to the specified piece.
    ///
    /// - Parameters:
    ///   - artID: Unique identifier of the art piece
    ///   - show: If `true`, immediately enters Art Mode and displays the art.
    ///           If `false`, sets the art but doesn't activate Art Mode. Default is `true`.
    /// - Throws: `TVError.connectionFailed` if not connected
    /// - Throws: `TVError.deviceNotFound` if art ID doesn't exist
    ///
    /// Example:
    /// ```swift
    /// // Select and show art immediately
    /// try await client.art.select("art_12345", show: true)
    ///
    /// // Select art without activating Art Mode
    /// try await client.art.select("art_12345", show: false)
    /// ```
    public func select(_ artID: String, show: Bool = true) async throws {
        #if canImport(OSLog)
        Logger.commands.info("Selecting art: \(artID), show: \(show)")
        #endif
        
        try await sendArtRequest([
            "request": "select_image",
            "content_id": artID,
            "show": show
        ])
    }
    
    /// Upload a custom image to the TV's art library
    ///
    /// Uploads a custom JPEG or PNG image to the Frame TV. The image can optionally
    /// include a matte style for framing.
    ///
    /// **Image Requirements:**
    /// - Format: JPEG or PNG
    /// - Maximum size: 20 MB (recommended)
    /// - Minimum dimensions: 1920x1080 (Full HD)
    /// - Recommended dimensions: 3840x2160 (4K) or TV's native resolution
    ///
    /// **Platform Notes:**
    /// - watchOS: Upload functionality is disabled due to memory constraints
    ///
    /// - Parameters:
    ///   - imageData: Image data in JPEG or PNG format
    ///   - imageType: Image format (`.jpeg` or `.png`)
    ///   - matte: Optional matte style for framing the image
    /// - Returns: Unique identifier for the uploaded art piece
    /// - Throws: `TVError.invalidImageFormat` if image format is invalid
    /// - Throws: `TVError.uploadFailed` if image data is too large or upload fails
    /// - Throws: `TVError.commandFailed` when invoked on unsupported platforms (e.g., watchOS)
    ///
    /// Note: Upload currently uses the REST API. D2D socket transfer support can be added in a future iteration for larger payloads.
    ///
    /// Example:
    /// ```swift
    /// let imageData = try Data(contentsOf: imageURL)
    /// let artID = try await client.art.upload(
    ///     imageData,
    ///     type: .jpeg,
    ///     matte: .modern
    /// )
    /// print("Uploaded art ID: \(artID)")
    /// ```
    public func upload(
        _ imageData: Data,
        type imageType: ImageType,
        matte: MatteStyle? = nil
    ) async throws -> String {
        // Platform check: Disable upload on watchOS due to memory constraints
        #if os(watchOS)
        throw TVError.commandFailed(
            code: 501,
            message: "Upload not supported on watchOS due to memory constraints"
        )
        #else
        // Image validation
        try validateImageData(imageData, type: imageType)

        do {
            return try await uploadViaD2DPipeline(
                imageData,
                type: imageType,
                matte: matte
            )
        } catch {
            guard shouldFallbackToREST(for: error), restClient != nil else { throw error }

            #if canImport(OSLog)
            Logger.commands.notice("D2D upload unavailable; falling back to REST pipeline. Error: \(String(describing: error))")
            #endif

            return try await uploadViaRESTPipeline(
                imageData,
                type: imageType,
                matte: matte
            )
        }
        #endif
    }
    
    /// Validate image data before upload
    /// - Parameters:
    ///   - imageData: Image data to validate
    ///   - imageType: Expected image format
    /// - Throws: `TVError.uploadFailed` if validation fails
    private func validateImageData(_ imageData: Data, type imageType: ImageType) throws {
        // Check if data is empty
        guard !imageData.isEmpty else {
            throw TVError.uploadFailed(reason: "Image data is empty")
        }
        
        // Check maximum size (20 MB recommended limit)
        let maxSize = 20 * 1024 * 1024 // 20 MB
        guard imageData.count <= maxSize else {
            throw TVError.uploadFailed(
                reason: "Image size (\(imageData.count) bytes) exceeds maximum limit of 20 MB"
            )
        }
        
        // Validate image format by checking magic bytes
        guard imageData.count >= 4 else {
            throw TVError.uploadFailed(reason: "Image data too small to determine format")
        }
        
        let bytes = [UInt8](imageData.prefix(4))
        
        switch imageType {
        case .jpeg:
            // JPEG magic bytes: FF D8 FF
            guard bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF else {
                throw TVError.invalidImageFormat(expected: .jpeg)
            }
        case .png:
            // PNG magic bytes: 89 50 4E 47
            guard bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 else {
                throw TVError.invalidImageFormat(expected: .png)
            }
        }
        
        #if canImport(OSLog)
        Logger.commands.debug("Image validation passed: \(imageType.rawValue), size: \(imageData.count) bytes")
        #endif
    }
    
    private func uploadViaD2DPipeline(
        _ imageData: Data,
        type imageType: ImageType,
        matte: MatteStyle?
    ) async throws -> String {
        let fileSize = imageData.count
        let fileTypeString = imageType == .jpeg ? "jpg" : "png"
        let matteIdentifier = (matte ?? .none).rawValue
        let connectionID = D2DSocketClient.generateConnectionID()

        #if canImport(OSLog)
        Logger.commands.info("Uploading image via D2D socket pipeline (bytes: \(fileSize))")
        #endif

        // Request socket credentials for the pending D2D transfer
        let initialPayload = try await performArtRequest(
            "send_image",
            additionalData: [
                "file_type": fileTypeString,
                "conn_info": [
                    "d2d_mode": "socket",
                    "connection_id": connectionID,
                    "id": getOrGenerateUUID()
                ],
                "image_date": buildImageTimestamp(),
                "matte_id": matteIdentifier,
                "file_size": fileSize
            ],
            timeout: .seconds(15)
        )

        try validateSendImageReady(payload: initialPayload)

      let connInfo = try parseConnInfo(from: initialPayload["conn_info"])
      let rawHost = connInfo["ip"] ?? connInfo["host"] ?? connInfo["ipaddr"]
      guard let host = normalizeString(rawHost),
          let port = coerceInt(connInfo["port"]),
          let sessionKey = normalizeString(connInfo["key"]) else {
            throw TVError.invalidResponse(details: "Incomplete D2D connection information")
        }

        let headerData = try buildD2DHeader(
            fileLength: fileSize,
            fileName: "swift-frame-upload-\(UUID().uuidString).\(fileTypeString)",
            fileType: fileTypeString,
            sessionKey: sessionKey
        )

        var transferData = Data()
        var headerLength = UInt32(headerData.count).bigEndian
        withUnsafeBytes(of: &headerLength) { buffer in
            transferData.append(contentsOf: buffer)
        }
        transferData.append(headerData)
        transferData.append(imageData)

        // Await the follow-up image_added event while streaming the payload
    async let completionResponse = waitForSendImageCompletion(timeout: .seconds(45))

        try await d2dClient.send(to: host, port: port, data: transferData)

    let finalResponse = try await completionResponse
    let finalPayload = finalResponse.value

        if let status = normalizeString(finalPayload["status"])?.lowercased(),
           status == "error" || status == "fail" {
            let code = coerceInt(finalPayload["error_code"] ?? finalPayload["code"]) ?? -1
            let message = normalizeString(finalPayload["error_text"] ?? finalPayload["message"]) ?? "Upload failed"
            throw TVError.commandFailed(code: code, message: message)
        }

        guard let contentID = normalizeString(finalPayload["content_id"] ?? finalPayload["contentId"]) else {
            throw TVError.invalidResponse(details: "Upload completion missing content identifier")
        }

        #if canImport(OSLog)
        Logger.commands.info("Upload completed via D2D. Content ID: \(contentID)")
        #endif

        return contentID
    }

    private func uploadViaRESTPipeline(
        _ imageData: Data,
        type imageType: ImageType,
        matte: MatteStyle?
    ) async throws -> String {
        guard let restClient else {
            throw TVError.connectionFailed(reason: "REST client not available")
        }

        #if canImport(OSLog)
        Logger.commands.info("Uploading image via REST fallback pipeline")
        #endif

        let fileExtension = imageType == .jpeg ? "jpg" : "png"
        let fileName = "art-\(UUID().uuidString).\(fileExtension)"
        let responseData = try await restClient.uploadImage(
            imageData,
            fileName: fileName,
            matte: matte
        )

        let contentID = try parseUploadResponse(responseData)

        #if canImport(OSLog)
        Logger.commands.info("Upload completed via REST. Content ID: \(contentID)")
        #endif

        return contentID
    }

    private func shouldFallbackToREST(for error: any Error) -> Bool {
        guard let tvError = error as? TVError else { return false }
        switch tvError {
        case .commandFailed(let code, _):
            return code == 501
        case .connectionFailed:
            return true
        case .timeout:
            return true
        case .invalidResponse:
            return true
        default:
            return false
        }
    }

    private func buildImageTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }

    private func validateSendImageReady(payload: [String: Any]) throws {
        if let status = normalizeString(payload["status"])?.lowercased(),
           status == "error" || status == "fail" {
            let code = coerceInt(payload["error_code"] ?? payload["code"]) ?? -1
            let message = normalizeString(payload["error_text"] ?? payload["message"]) ?? "Send image request failed"
            throw TVError.commandFailed(code: code, message: message)
        }

        guard let event = normalizeString(payload["event"])?.lowercased() else {
            throw TVError.invalidResponse(details: "Missing event for send_image response")
        }

        if event == "error" {
            let code = coerceInt(payload["error_code"] ?? payload["code"]) ?? -1
            let message = normalizeString(payload["error_text"] ?? payload["message"]) ?? "Send image request failed"
            throw TVError.commandFailed(code: code, message: message)
        }

        guard event == "ready_to_use" else {
            throw TVError.invalidResponse(details: "Unexpected send_image handshake event: \(event)")
        }

        guard payload["conn_info"] != nil else {
            throw TVError.invalidResponse(details: "Missing D2D connection info")
        }
    }

    private func parseConnInfo(from value: Any?) throws -> [String: Any] {
        if let dictionary = value as? [String: Any] {
            return dictionary
        }
        if let string = normalizeString(value),
           let data = string.data(using: .utf8),
           let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dictionary
        }
        throw TVError.invalidResponse(details: "Unable to parse conn_info payload")
    }

    private func buildD2DHeader(
        fileLength: Int,
        fileName: String,
        fileType: String,
        sessionKey: String
    ) throws -> Data {
        let header: [String: Any] = [
            "num": 0,
            "total": 1,
            "fileLength": fileLength,
            "fileName": fileName,
            "fileType": fileType,
            "secKey": sessionKey,
            "version": "0.0.1"
        ]

        return try JSONSerialization.data(withJSONObject: header)
    }

    private func waitForSendImageCompletion(timeout: Duration) async throws -> ArtResponse {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        var remaining = timeout

        while true {
            // The TV emits additional d2d_service_message events during image ingestion
            let response = try await awaitFollowupResponse(
                for: "send_image",
                timeout: remaining
            )
            let payload = response.value

            if let status = normalizeString(payload["status"])?.lowercased(),
               status == "error" || status == "fail" {
                let code = coerceInt(payload["error_code"] ?? payload["code"]) ?? -1
                let message = normalizeString(payload["error_text"] ?? payload["message"]) ?? "Upload failed"
                throw TVError.commandFailed(code: code, message: message)
            }

            if let event = normalizeString(payload["event"])?.lowercased() {
                if event == "image_added" || event == "image_synced" {
                    return response
                }
                if event == "error" {
                    let code = coerceInt(payload["error_code"] ?? payload["code"]) ?? -1
                    let message = normalizeString(payload["error_text"] ?? payload["message"]) ?? "Upload failed"
                    throw TVError.commandFailed(code: code, message: message)
                }
            }

            let now = clock.now
            let newRemaining = deadline - now
            guard newRemaining > .zero else {
                throw TVError.timeout(operation: "send_image_completion")
            }
            remaining = newRemaining
        }
    }

    // MARK: - Art Response Handling
    
    private func performArtRequest(
        _ request: String,
        additionalData: [String: Any] = [:],
        timeout: Duration? = nil
    ) async throws -> [String: Any] {
        var payload = additionalData
        payload["request"] = request
        return try await awaitResponse(
            for: request,
            payload: payload,
            timeout: timeout ?? responseTimeout
        )
    }
    
    private func awaitResponse(
        for request: String,
        payload: [String: Any],
        timeout: Duration
    ) async throws -> [String: Any] {
        let sendPayload = ArtPayload(value: payload)
        let response = try await enqueuePending(
            for: request,
            timeout: timeout
        ) {
            try await self.sendArtRequest(sendPayload.value)
        }
        return response.value
    }

    private func awaitFollowupResponse(
        for request: String,
        timeout: Duration
    ) async throws -> ArtResponse {
        try await enqueuePending(
            for: request,
            timeout: timeout,
            sendAction: nil
        )
    }

    private func enqueuePending(
        for request: String,
        timeout: Duration,
        sendAction: (@Sendable () async throws -> Void)?
    ) async throws -> ArtResponse {
        let pending = PendingContinuation()
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ArtResponse, any Error>) in
            pending.continuation = continuation
            var queue = pendingResponses[request] ?? []
            queue.append(pending)
            pendingResponses[request] = queue

            pending.timeoutTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: timeout)
                await self.completePending(
                    for: request,
                    matching: pending,
                    result: .failure(TVError.timeout(operation: request))
                )
            }

            if let sendAction {
                Task { [weak self] in
                    guard let self else { return }
                    await self.performSendAction(
                        sendAction,
                        request: request,
                        pending: pending
                    )
                }
            }
        }
    }

    private func performSendAction(
        _ action: @Sendable () async throws -> Void,
        request: String,
        pending: PendingContinuation
    ) async {
        do {
            try await action()
        } catch {
            await completePending(
                for: request,
                matching: pending,
                result: .failure(error)
            )
        }
    }
    
    private func completePending(
        for request: String,
        matching target: PendingContinuation,
        result: Result<ArtResponse, any Error>
    ) async {
        guard var queue = pendingResponses[request] else { return }
        guard let index = queue.firstIndex(where: { $0.id == target.id }) else { return }
        let pending = queue.remove(at: index)
        pendingResponses[request] = queue.isEmpty ? nil : queue
        pending.complete(with: result)
    }
    
    private func completePending(
        for request: String,
        result: Result<ArtResponse, any Error>
    ) async {
        guard var queue = pendingResponses[request], !queue.isEmpty else { return }
        let pending = queue.removeFirst()
        pendingResponses[request] = queue.isEmpty ? nil : queue
        pending.complete(with: result)
    }
    
    private func failAllPending(with error: any Error) async {
        guard !pendingResponses.isEmpty else { return }
        let queues = pendingResponses.values
        pendingResponses.removeAll()
        for queue in queues {
            for pending in queue {
                pending.complete(with: .failure(error))
            }
        }
    }
    
    private func handleIncomingMessage(_ data: Data) async {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventRaw = json["event"] as? String else {
            return
        }
        let event = eventRaw.lowercased()
        let payload = extractPayload(from: json["data"])
        switch event {
        case "art_app_response":
            guard let payload, let response = responseIdentifier(from: payload) else { return }
            await completePending(for: response, result: .success(ArtResponse(value: payload)))
        case "art_list":
            guard var payload else { return }
            if payload["response"] == nil { payload["response"] = "get_content_list" }
            await completePending(for: "get_content_list", result: .success(ArtResponse(value: payload)))
        case "art_mode_status":
            guard var payload else { return }
            if payload["response"] == nil { payload["response"] = "get_artmode_status" }
            await completePending(for: "get_artmode_status", result: .success(ArtResponse(value: payload)))
        case "art_select":
            guard var payload else { return }
            if payload["response"] == nil { payload["response"] = "select_image" }
            await completePending(for: "select_image", result: .success(ArtResponse(value: payload)))
        case "art_filter_list":
            guard var payload else { return }
            if payload["response"] == nil { payload["response"] = "get_photo_filter_list" }
            await completePending(for: "get_photo_filter_list", result: .success(ArtResponse(value: payload)))
        case "d2d_service_message":
            guard var payload else { return }
            
            // For d2d_service_message, the event field in the nested payload is the request identifier
            if payload["response"] == nil {
                if let eventName = normalizeString(payload["event"]) {
                    payload["response"] = eventName
                } else if let requestName = normalizeString(payload["request"]) {
                    payload["response"] = requestName
                }
            }
            
            let eventName = normalizeString(payload["event"])?.lowercased()
            let status = normalizeString(payload["status"])?.lowercased()
            if eventName == "error" || status == "error" || status == "fail" {
                let code = coerceInt(payload["error_code"] ?? payload["code"]) ?? -1
                let message = normalizeString(payload["error_text"] ?? payload["message"]) ?? "D2D transfer failed"
                let requestName = responseIdentifier(from: payload) ?? "d2d_service_message"
                await completePending(for: requestName, result: .failure(TVError.commandFailed(code: code, message: message)))
            } else if let requestName = responseIdentifier(from: payload) {
                await completePending(for: requestName, result: .success(ArtResponse(value: payload)))
            }
        case "ms.error":
            guard let payload else { return }
            let message = normalizeString(payload["message"]) ?? "Command failed"
            let code = coerceInt(payload["code"]) ?? -1
            let error = TVError.commandFailed(code: code, message: message)
            if let request = responseIdentifier(from: payload) {
                await completePending(for: request, result: .failure(error))
            } else {
                await failAllPending(with: error)
            }
        default:
            break
        }
    }
    
    private func responseIdentifier(from payload: [String: Any]) -> String? {
        if let response = normalizeString(payload["response"]) {
            return response
        }
        if let request = normalizeString(payload["request"]) {
            return request
        }
        return nil
    }
    
    private func extractPayload(from value: Any?) -> [String: Any]? {
        if let dictionary = value as? [String: Any] {
            return dictionary
        }
        if let string = value as? String,
           let data = string.data(using: .utf8),
           let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dictionary
        }
        return nil
    }
    
    private func coerceArrayOfDictionaries(_ value: Any?) -> [[String: Any]]? {
        if let array = value as? [[String: Any]] {
            return array
        }
        if let string = value as? String,
           let data = string.data(using: .utf8),
           let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return array
        }
        return nil
    }
    
    private func parseArtPiece(from dictionary: [String: Any]) -> ArtPiece? {
        guard let identifier = normalizeString(
            dictionary["content_id"] ?? dictionary["contentId"] ?? dictionary["id"]
        ) else { return nil }
        let title = normalizeString(
            dictionary["title"] ?? dictionary["name"] ?? dictionary["content_name"]
        ) ?? "Untitled"
        let category = parseArtCategory(from: dictionary["category"])
        let imageType = parseImageType(from: dictionary["image_type"] ?? dictionary["imageType"])
        let thumbnailURL = buildThumbnailURL(from: dictionary["thumbnail_url"] ?? dictionary["thumbnail"] ?? dictionary["image_url"])
        let matteStyle = parseMatteStyle(from: dictionary["matte_id"] ?? dictionary["matteId"])
        let filter = parseFilter(from: dictionary["filter_id"] ?? dictionary["filter"])
        let uploadDate = parseDate(from: dictionary["image_date"] ?? dictionary["date"] ?? dictionary["uploaded_at"])
        let fileSize = coerceInt(dictionary["file_size"] ?? dictionary["size"])
        return ArtPiece(
            id: identifier,
            title: title,
            category: category,
            thumbnailURL: thumbnailURL,
            imageType: imageType,
            matteStyle: matteStyle,
            filter: filter,
            uploadDate: uploadDate,
            fileSize: fileSize
        )
    }
    
    private func parseArtCategory(from value: Any?) -> ArtCategory {
        guard let string = normalizeString(value)?.lowercased() else { return .preloaded }
        if string.contains("store") || string.contains("purchase") {
            return .purchased
        }
        if string.contains("my") {
            return .uploaded
        }
        return .preloaded
    }
    
    private func parseImageType(from value: Any?) -> ImageType {
        guard let string = normalizeString(value)?.lowercased() else { return .jpeg }
        if string.contains("png") {
            return .png
        }
        return .jpeg
    }
    
    private func parseMatteStyle(from value: Any?) -> MatteStyle? {
        guard let string = normalizeString(value), !string.isEmpty else { return nil }
        if string.lowercased() == "none" {
            return nil
        }
        if let style = MatteStyle(rawValue: string) {
            return style
        }
        return MatteStyle(rawValue: string.lowercased())
    }
    
    private func parseFilter(from value: Any?) -> PhotoFilter? {
        guard let string = normalizeString(value) else { return nil }
        if let filter = PhotoFilter(rawValue: string) {
            return filter
        }
        return PhotoFilter(rawValue: string.lowercased())
    }
    
    private func parseDate(from value: Any?) -> Date? {
        if let timeInterval = value as? TimeInterval {
            return Date(timeIntervalSince1970: timeInterval)
        }
        if let intValue = coerceInt(value) {
            return Date(timeIntervalSince1970: TimeInterval(intValue))
        }
        guard let string = normalizeString(value) else { return nil }
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: string) {
            return date
        }
        let formats = [
            "yyyy:MM:dd HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy/MM/dd HH:mm:ss"
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
    
    private func buildThumbnailURL(from value: Any?) -> URL? {
        guard let path = normalizeString(value) else { return nil }
        if let url = URL(string: path), url.scheme != nil {
            return url
        }
        if path.hasPrefix("/"), let base = restClient?.serviceBaseURL {
            return URL(string: path, relativeTo: base)?.absoluteURL
        }
        return nil
    }
    
    private func coerceInt(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = normalizeString(value) {
            return Int(string)
        }
        return nil
    }
    
    private func normalizeString(_ value: Any?) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }
    
    /// Parse REST upload response and extract content identifier
    /// - Parameter data: Raw response data from REST API
    /// - Returns: Content identifier string
    /// - Throws: `TVError.uploadFailed` when the response is invalid or indicates failure
    private func parseUploadResponse(_ data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TVError.invalidResponse(details: "Unable to decode upload response")
        }
        
        if let status = json["status"] {
            if let statusString = status as? String, statusString.lowercased() != "success" {
                let message = (json["message"] as? String) ?? "Upload failed with status \(statusString)"
                throw TVError.uploadFailed(reason: message)
            }
            if let statusCode = status as? Int, !(200...299).contains(statusCode) {
                let message = (json["message"] as? String) ?? "Upload failed with status code \(statusCode)"
                throw TVError.uploadFailed(reason: message)
            }
        }
        
        if let contentID = json["content_id"] as? String {
            return contentID
        }
        if let contentID = json["contentId"] as? String {
            return contentID
        }
        
        if let message = json["message"] as? String {
            throw TVError.uploadFailed(reason: message)
        }
        
        throw TVError.invalidResponse(details: "Upload response missing content identifier")
    }
    
    /// Delete a single art piece from the TV's library
    ///
    /// Removes a custom uploaded image from the art library. Built-in art
    /// pieces cannot be deleted.
    ///
    /// - Parameter artID: Unique identifier of the art piece to delete
    /// - Throws: `TVError.connectionFailed` if not connected
    /// - Throws: `TVError.commandFailed` if deletion fails
    ///
    /// Example:
    /// ```swift
    /// try await client.art.delete("art_12345")
    /// ```
    public func delete(_ artID: String) async throws {
        try await deleteMultiple([artID])
    }
    
    /// Delete multiple art pieces from the TV's library
    ///
    /// Removes multiple custom uploaded images in a single operation.
    /// This is more efficient than calling `delete()` multiple times.
    ///
    /// - Parameter artIDs: Array of art piece identifiers to delete
    /// - Throws: `TVError.connectionFailed` if not connected
    /// - Throws: `TVError.commandFailed` if deletion fails
    ///
    /// Example:
    /// ```swift
    /// try await client.art.deleteMultiple(["art_001", "art_002", "art_003"])
    /// ```
    public func deleteMultiple(_ artIDs: [String]) async throws {
        #if canImport(OSLog)
        Logger.commands.info("Deleting \(artIDs.count) art pieces")
        #endif
        
        let contentIDList = artIDs.map { ["content_id": $0] }
        
        try await sendArtRequest([
            "request": "delete_image_list",
            "content_id_list": contentIDList
        ])
    }
    
    /// Get a thumbnail preview of an art piece
    ///
    /// Downloads a JPEG thumbnail of the specified art piece.
    /// Thumbnails are typically 480x270 pixels.
    ///
    /// - Parameter artID: Unique identifier of the art piece
    /// - Returns: Thumbnail image data in JPEG format
    /// - Throws: `TVError.connectionFailed` if not connected
    /// - Throws: `TVError.invalidResponse` if thumbnail cannot be retrieved
    /// - Throws: `TVError.commandFailed` if D2D socket implementation is not complete
    ///
    /// Note: Full implementation requires D2D socket support.
    ///
    /// Example:
    /// ```swift
    /// let thumbnailData = try await client.art.thumbnail(for: "art_12345")
    /// // Use thumbnailData to display preview
    /// ```
    public func thumbnail(for artID: String) async throws -> Data {
        #if canImport(OSLog)
        Logger.commands.debug("Requesting thumbnail for: \(artID)")
        #endif
        
        let connectionID = D2DSocketClient.generateConnectionID()
        
        try await sendArtRequest([
            "request": "get_thumbnail",
            "content_id": artID,
            "conn_info": [
                "d2d_mode": "socket",
                "connection_id": connectionID,
                "id": getOrGenerateUUID()
            ]
        ])
        
        // Note: Full implementation would:
        // 1. Wait for response with connection info
        // 2. Connect to D2D socket
        // 3. Read header (4 bytes length + JSON header)
        // 4. Read thumbnail data based on fileLength
        // 5. Return thumbnail data
        
        throw TVError.commandFailed(
            code: 501,
            message: "Thumbnail download requires full D2D socket implementation"
        )
    }
    
    /// Check if Art Mode is currently active
    ///
    /// Determines whether the TV is currently in Art Mode (displaying artwork)
    /// or in normal TV mode.
    ///
    /// - Returns: `true` if Art Mode is active, `false` otherwise
    /// - Throws: `TVError.artModeNotSupported` if TV doesn't support Art Mode
    /// - Throws: `TVError.connectionFailed` if not connected
    ///
    /// Note: Full implementation requires WebSocket response handling.
    ///
    /// Example:
    /// ```swift
    /// if try await client.art.isArtModeActive() {
    ///     print("TV is in Art Mode")
    /// } else {
    ///     print("TV is in normal mode")
    /// }
    /// ```
    public func isArtModeActive() async throws -> Bool {
        #if canImport(OSLog)
        Logger.commands.debug("Checking art mode status")
        #endif
        
        let response = try await performArtRequest("get_artmode_status")
        if let status = (response["status"] ?? response["value"]) as? String {
            return status.lowercased() == "on" || status == "1"
        }
        if let isOn = response["is_on"] as? Bool {
            return isOn
        }
        throw TVError.invalidResponse(details: "Unable to determine Art Mode status")
    }
    
    /// Toggle Art Mode on or off
    ///
    /// Switches the TV between Art Mode (displaying artwork) and normal TV mode.
    /// When enabled, the TV displays the currently selected art piece.
    ///
    /// - Parameter enabled: `true` to enable Art Mode, `false` to disable
    /// - Throws: `TVError.connectionFailed` if not connected
    /// - Throws: `TVError.commandFailed` if mode switch fails
    ///
    /// Example:
    /// ```swift
    /// // Enable Art Mode
    /// try await client.art.setArtMode(enabled: true)
    ///
    /// // Disable Art Mode
    /// try await client.art.setArtMode(enabled: false)
    /// ```
    public func setArtMode(enabled: Bool) async throws {
        #if canImport(OSLog)
        Logger.commands.info("Setting art mode: \(enabled)")
        #endif
        
        try await sendArtRequest([
            "request": "set_artmode_status",
            "value": enabled ? "on" : "off"
        ])
    }
    
    /// List all available photo filters
    ///
    /// Retrieves the list of photo filters that can be applied to artwork.
    /// Common filters include watercolor, oil painting, pencil sketch, etc.
    ///
    /// - Returns: Array of available photo filters (currently returns empty array pending WebSocket response handler)
    /// - Throws: `TVError.artModeNotSupported` if TV doesn't support Art Mode
    /// - Throws: `TVError.connectionFailed` if not connected
    ///
    /// Note: Full implementation requires WebSocket response handling.
    ///
    /// Example:
    /// ```swift
    /// let filters = try await client.art.availableFilters()
    /// for filter in filters {
    ///     print("Filter: \(filter.rawValue)")
    /// }
    /// ```
    public func availableFilters() async throws -> [PhotoFilter] {
        #if canImport(OSLog)
        Logger.commands.debug("Requesting photo filter list")
        #endif
        
        let response = try await performArtRequest("get_photo_filter_list")
        if let filters = response["filter_list"] as? [[String: Any]] {
            return filters.compactMap { parseFilter(from: $0["id"] ?? $0["filter_id"]) }
        }
        if let filters = response["filters"] as? [String] {
            return filters.compactMap { parseFilter(from: $0) }
        }
        if let filter = parseFilter(from: response["filter_id"] ?? response["filter"]) {
            return [filter]
        }
        return []
    }
    
    /// Apply a photo filter to an art piece
    ///
    /// Applies a visual filter effect to the specified artwork.
    /// The filter modifies how the image is displayed on the TV.
    ///
    /// Available filters (if supported by TV):
    /// - `.watercolor` - Watercolor painting effect
    /// - `.pencilSketch` - Pencil sketch effect
    /// - `.oilPainting` - Oil painting effect
    /// - `.vintage` - Vintage/aged photo effect
    /// - `.none` - Remove all filters
    ///
    /// - Parameters:
    ///   - filter: Photo filter to apply
    ///   - artID: Unique identifier of the art piece
    /// - Throws: `TVError.connectionFailed` if not connected
    /// - Throws: `TVError.commandFailed` if filter application fails
    ///
    /// Example:
    /// ```swift
    /// try await client.art.applyFilter(.watercolor, to: "art_12345")
    /// ```
    public func applyFilter(_ filter: PhotoFilter, to artID: String) async throws {
        #if canImport(OSLog)
        Logger.commands.info("Applying filter \(filter.rawValue) to art: \(artID)")
        #endif
        
        try await sendArtRequest([
            "request": "set_photo_filter",
            "content_id": artID,
            "filter_id": filter.rawValue
        ])
    }
}

// MARK: - Timeout Helper

/// Error thrown when operation times out
private struct TimeoutError: Error {}

/// Execute operation with timeout
/// - Parameters:
///   - timeout: Maximum duration to wait
///   - operation: Async operation to execute
/// - Throws: TimeoutError if operation exceeds timeout
/// - Returns: Result of operation
private func withTimeout<T: Sendable>(
    _ timeout: Duration,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(for: timeout)
            throw TimeoutError()
        }
        
        guard let result = try await group.next() else {
            throw TimeoutError()
        }
        
        group.cancelAll()
        return result
    }
}
