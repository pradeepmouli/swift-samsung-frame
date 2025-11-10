// TVClient - Main client for Samsung TV interaction
// Implements TVClientProtocol with connection management and control interfaces

import Foundation
#if canImport(OSLog)
import OSLog
#endif

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
        tokenStorage: (any TokenStorageProtocol)? = nil
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
        
        // Create WebSocket URL
        let wsURL = URL(string: "wss://\(host):\(port)/api/v2/channels/samsung.remote.control")!
        
        // Initialize clients
        let wsClient = WebSocketClient()
        self.webSocketClient = wsClient
        
        let restURL = URL(string: "http://\(host):8001")!
        self.restClient = RESTClient(baseURL: restURL)
        
        do {
            // Connect WebSocket
            try await wsClient.connect(to: wsURL)
            
            // Try to retrieve stored token
            var authToken: String?
            if let storage = tokenStorage {
                if let storedToken = try? await storage.retrieve(for: device.id) {
                    authToken = storedToken.value
                }
            }
            
            // Send authentication message
            await newSession.updateState(.authenticating)
            await notifyStateChange(.authenticating)
            
            let authMessage = WebSocketMessage.authentication(token: authToken)
            let authData = try JSONEncoder().encode(authMessage)
            try await wsClient.send(authData)
            
            // Wait for auth response (simplified - production would parse response)
            try await Task.sleep(for: .seconds(1))
            
            await newSession.updateState(.connected)
            await newSession.setWebSocket(wsClient)
            await notifyStateChange(.connected)
            
            #if canImport(OSLog)
            Logger.connection.info("Connected successfully")
            #endif
            
            // Inject websocket into controllers
            await _remote.setWebSocket(wsClient)
            await _apps.setWebSocket(wsClient)
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
        await session.clearWebSocket()
        
        await session.updateState(.disconnected)
        await notifyStateChange(.disconnected)
        
        self.session = nil
        self.webSocketClient = nil
        self.restClient = nil
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
}

// MARK: - RemoteControl Implementation

actor RemoteControl: RemoteControlProtocol {
    private var webSocket: WebSocketClient?
    
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
        try await webSocket.send(data)
    }
    
    public func sendKeys(_ keys: [KeyCode], delay: Duration = .milliseconds(100)) async throws {
        for key in keys {
            try await sendKey(key)
            try await Task.sleep(for: delay)
        }
    }
    
    public func power() async throws {
        try await sendKey(.power)
    }
    
    public func volumeUp(steps: Int = 1) async throws {
        for _ in 0..<steps {
            try await sendKey(.volumeUp)
            try await Task.sleep(for: .milliseconds(100))
        }
    }
    
    public func volumeDown(steps: Int = 1) async throws {
        for _ in 0..<steps {
            try await sendKey(.volumeDown)
            try await Task.sleep(for: .milliseconds(100))
        }
    }
    
    public func mute() async throws {
        try await sendKey(.mute)
    }
    
    public func navigate(_ direction: NavigationDirection) async throws {
        try await sendKey(direction.keyCode)
    }
    
    public func enter() async throws {
        try await sendKey(.enter)
    }
    
    public func back() async throws {
        try await sendKey(.back)
    }
    
    public func home() async throws {
        try await sendKey(.home)
    }
}

// MARK: - AppManagement Stub

actor AppManagement: AppManagementProtocol {
    private var webSocket: WebSocketClient?
    
    func setWebSocket(_ ws: WebSocketClient) {
        self.webSocket = ws
    }
    
    public func list() async throws -> [TVApp] {
        // Stub implementation
        return []
    }
    
    public func launch(_ appID: String) async throws {
        // Stub implementation
    }
    
    public func close(_ appID: String) async throws {
        // Stub implementation
    }
    
    public func status(of appID: String) async throws -> AppStatus {
        // Stub implementation
        return .stopped
    }
    
    public func install(_ appID: String) async throws {
        throw TVError.commandFailed(code: 501, message: "Not implemented")
    }
}

// MARK: - ArtController Stub

actor ArtController: ArtControllerProtocol {
    private var webSocket: WebSocketClient?
    private var restClient: RESTClient?
    
    func setWebSocket(_ ws: WebSocketClient) {
        self.webSocket = ws
    }
    
    func setRESTClient(_ client: RESTClient?) {
        self.restClient = client
    }
    
    public func isSupported() async throws -> Bool {
        // Stub implementation
        return false
    }
    
    public func listAvailable() async throws -> [ArtPiece] {
        // Stub implementation
        return []
    }
    
    public func current() async throws -> ArtPiece {
        throw TVError.artModeNotSupported
    }
    
    public func select(_ artID: String, show: Bool = true) async throws {
        // Stub implementation
    }
    
    public func upload(
        _ imageData: Data,
        type imageType: ImageType,
        matte: MatteStyle? = nil
    ) async throws -> String {
        throw TVError.artModeNotSupported
    }
    
    public func delete(_ artID: String) async throws {
        // Stub implementation
    }
    
    public func deleteMultiple(_ artIDs: [String]) async throws {
        // Stub implementation
    }
    
    public func thumbnail(for artID: String) async throws -> Data {
        throw TVError.artModeNotSupported
    }
    
    public func isArtModeActive() async throws -> Bool {
        return false
    }
    
    public func setArtMode(enabled: Bool) async throws {
        // Stub implementation
    }
    
    public func availableFilters() async throws -> [PhotoFilter] {
        return []
    }
    
    public func applyFilter(_ filter: PhotoFilter, to artID: String) async throws {
        // Stub implementation
    }
}
