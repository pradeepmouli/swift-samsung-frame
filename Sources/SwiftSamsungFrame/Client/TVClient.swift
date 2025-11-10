import Foundation

#if canImport(os)
import os
#endif

/// Main TV client for controlling Samsung TVs
public class TVClient: TVClientProtocol, @unchecked Sendable {
    private let session: ConnectionSession
    private let webSocketClient: WebSocketClient
    private let restClient: RESTClient
    private let tokenStorage: any TokenStorageProtocol
    private weak var delegate: (any TVClientDelegate)?
    
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3
    
    /// Current TV device
    public private(set) var device: TVDevice?
    
    /// Remote control interface
    public let remote: any RemoteControlProtocol
    
    /// Application management interface
    public let apps: any AppManagementProtocol
    
    /// Art controller interface
    public let art: any ArtControllerProtocol
    
    /// Creates a new TV client
    /// - Parameter tokenStorage: Token storage implementation (default: KeychainTokenStorage)
    public init(tokenStorage: any TokenStorageProtocol = KeychainTokenStorage.shared) {
        let tempDevice = TVDevice(id: "temp", ipAddress: "0.0.0.0")
        self.session = ConnectionSession(device: tempDevice)
        self.webSocketClient = WebSocketClient()
        self.restClient = RESTClient(baseURL: tempDevice.restBaseURL)
        self.tokenStorage = tokenStorage
        
        // Initialize protocol implementations (we'll create placeholder classes for now)
        self.remote = RemoteControl(webSocketClient: webSocketClient)
        self.apps = AppManagement(webSocketClient: webSocketClient, restClient: restClient)
        self.art = ArtController(webSocketClient: webSocketClient, restClient: restClient, device: tempDevice)
        
        setupWebSocketCallbacks()
    }
    
    /// Current connection state
    public var state: ConnectionState {
        get async {
            await session.state
        }
    }
    
    /// Connects to a TV
    /// - Parameters:
    ///   - device: TV device to connect to
    ///   - delegate: Optional delegate for connection events
    public func connect(to device: TVDevice, delegate: (any TVClientDelegate)? = nil) async throws {
        #if canImport(os)
        Logger.connection.info("Connecting to TV: \(device.ipAddress)")
        #endif
        
        self.device = device
        self.delegate = delegate
        
        await session.updateState(.connecting)
        await notifyStateChange(.connecting)
        
        // Try to load existing token
        let savedToken = await tokenStorage.loadToken(for: device.id)
        
        do {
            // Connect WebSocket
            try await webSocketClient.connect(to: device.websocketURL)
            
            // Authenticate
            await session.updateState(.authenticating)
            await notifyStateChange(.authenticating)
            
            try await authenticate(token: savedToken)
            
            await session.updateState(.authenticated)
            await notifyStateChange(.authenticated)
            
            reconnectAttempts = 0
            
            #if canImport(os)
            Logger.connection.info("Successfully connected to TV")
            #endif
        } catch {
            await session.updateState(.failed)
            await notifyStateChange(.failed)
            
            let tvError = error as? TVError ?? TVError.connectionFailed(reason: error.localizedDescription)
            await notifyError(tvError)
            
            throw tvError
        }
    }
    
    /// Disconnects from the TV
    public func disconnect() async {
        #if canImport(os)
        Logger.connection.info("Disconnecting from TV")
        #endif
        
        reconnectTask?.cancel()
        reconnectTask = nil
        
        await webSocketClient.disconnect()
        await session.updateState(.disconnected)
        await notifyStateChange(.disconnected)
    }
    
    /// Retrieves device information
    /// - Returns: Dictionary of device info
    public func deviceInfo() async throws -> [String: Any] {
        guard let device = device else {
            throw TVError.notConnected
        }
        
        #if canImport(os)
        Logger.connection.info("Retrieving device info")
        #endif
        
        // Try to get device info via REST API
        do {
            let data = try await restClient.get("/")
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json
            }
        } catch {
            // If REST fails, return basic device info
            #if canImport(os)
            Logger.connection.warning("Failed to get device info via REST: \(error.localizedDescription)")
            #endif
        }
        
        // Return basic device info
        return [
            "id": device.id,
            "ipAddress": device.ipAddress,
            "modelName": device.modelName ?? "Unknown",
            "name": device.name ?? "Samsung TV",
            "firmwareVersion": device.firmwareVersion ?? "Unknown"
        ]
    }
    
    // MARK: - Private Methods
    
    private func setupWebSocketCallbacks() {
        Task { [weak self] in
            guard let self = self else { return }
            
            await self.webSocketClient.setMessageCallback { [weak self] data in
                await self?.handleWebSocketMessage(data)
            }
            
            await self.webSocketClient.setStateChangeCallback { [weak self] connected in
                if !connected {
                    await self?.handleDisconnection()
                }
            }
        }
    }
    
    private func authenticate(token: AuthenticationToken?) async throws {
        let deviceName = "SwiftSamsungFrame"
        
        // Send authentication message
        let authMessage = WebSocketAuthMessage(
            params: .init(name: deviceName, token: token?.value)
        )
        
        try await webSocketClient.sendJSON(authMessage)
        
        // Wait for authentication response
        // In a real implementation, we'd listen for the response message
        // For now, we'll simulate a delay
        try await Task.sleep(for: .seconds(1))
        
        // If no token was provided, request pairing approval
        if token == nil {
            let approved = await delegate?.tvClientRequiresPairing() ?? false
            
            if !approved {
                throw TVError.authenticationFailed(reason: "User denied pairing request")
            }
            
            // In a real implementation, we'd wait for the TV to send a token
            // For now, we'll create a token
            let newToken = AuthenticationToken(
                value: UUID().uuidString,
                deviceId: device?.id ?? "unknown"
            )
            
            await session.setToken(newToken)
            _ = await tokenStorage.saveToken(newToken, for: newToken.deviceId)
        } else if let existingToken = token {
            await session.setToken(existingToken)
        }
    }
    
    private func handleWebSocketMessage(_ data: Data) async {
        #if canImport(os)
        if let message = String(data: data, encoding: .utf8) {
            Logger.networking.debug("Received WebSocket message: \(message)")
        }
        #endif
        
        // Parse and handle different message types
        // This would include authentication responses, command acknowledgments, etc.
        
        await session.recordActivity()
    }
    
    private func handleDisconnection() async {
        let currentState = await session.state
        guard currentState == .authenticated || currentState == .connected else {
            return
        }
        
        #if canImport(os)
        Logger.connection.warning("WebSocket disconnected, attempting reconnection")
        #endif
        
        await session.updateState(.reconnecting)
        await notifyStateChange(.reconnecting)
        
        await attemptReconnection()
    }
    
    private func attemptReconnection() async {
        guard let device = device else { return }
        guard reconnectAttempts < maxReconnectAttempts else {
            await session.updateState(.failed)
            await notifyStateChange(.failed)
            await notifyError(.connectionFailed(reason: "Max reconnection attempts reached"))
            return
        }
        
        reconnectAttempts += 1
        
        // Exponential backoff: 1s, 2s, 4s
        let delay = min(pow(2.0, Double(reconnectAttempts - 1)), 4.0)
        try? await Task.sleep(for: .seconds(Int(delay)))
        
        do {
            try await connect(to: device, delegate: delegate)
            reconnectAttempts = 0
        } catch {
            await attemptReconnection()
        }
    }
    
    private func notifyStateChange(_ state: ConnectionState) async {
        await delegate?.tvClient(didChangeState: state)
    }
    
    private func notifyError(_ error: TVError) async {
        await delegate?.tvClient(didEncounterError: error)
    }
}

// MARK: - Placeholder Implementations

/// Placeholder RemoteControl implementation (will be fully implemented in Phase 4)
private final class RemoteControl: RemoteControlProtocol, @unchecked Sendable {
    private let webSocketClient: WebSocketClient
    
    init(webSocketClient: WebSocketClient) {
        self.webSocketClient = webSocketClient
    }
    
    func sendKey(_ keyCode: KeyCode) async throws {
        let command = WebSocketCommand(params: .init(cmd: "Click", dataOfCmd: keyCode.rawValue))
        try await webSocketClient.sendJSON(command)
    }
    
    func sendKeys(_ keyCodes: [KeyCode], delay: Int = 300) async throws {
        for keyCode in keyCodes {
            try await sendKey(keyCode)
            try await Task.sleep(for: .milliseconds(delay))
        }
    }
    
    func power() async throws {
        try await sendKey(.power)
    }
    
    func volumeUp(steps: Int = 1) async throws {
        for _ in 0..<steps {
            try await sendKey(.volumeUp)
            try await Task.sleep(for: .milliseconds(200))
        }
    }
    
    func volumeDown(steps: Int = 1) async throws {
        for _ in 0..<steps {
            try await sendKey(.volumeDown)
            try await Task.sleep(for: .milliseconds(200))
        }
    }
    
    func mute() async throws {
        try await sendKey(.mute)
    }
    
    func navigate(_ direction: NavigationDirection) async throws {
        try await sendKey(direction.keyCode)
    }
    
    func enter() async throws {
        try await sendKey(.enter)
    }
    
    func back() async throws {
        try await sendKey(.back)
    }
    
    func home() async throws {
        try await sendKey(.home)
    }
}

/// Placeholder AppManagement implementation (will be fully implemented in Phase 6)
private final class AppManagement: AppManagementProtocol, @unchecked Sendable {
    private let webSocketClient: WebSocketClient
    private let restClient: RESTClient
    
    init(webSocketClient: WebSocketClient, restClient: RESTClient) {
        self.webSocketClient = webSocketClient
        self.restClient = restClient
    }
    
    func list() async throws -> [TVApp] {
        // Placeholder implementation
        return []
    }
    
    func launch(appId: String) async throws {
        // Placeholder implementation
    }
    
    func close(appId: String) async throws {
        // Placeholder implementation
    }
    
    func status(appId: String) async throws -> AppStatus {
        // Placeholder implementation
        return .unknown
    }
    
    func install(appId: String) async throws {
        throw TVError.unsupportedOperation(operation: "install")
    }
}

/// Placeholder ArtController implementation (will be fully implemented in Phase 7)
private final class ArtController: ArtControllerProtocol, @unchecked Sendable {
    private let webSocketClient: WebSocketClient
    private let restClient: RESTClient
    private let device: TVDevice
    
    init(webSocketClient: WebSocketClient, restClient: RESTClient, device: TVDevice) {
        self.webSocketClient = webSocketClient
        self.restClient = restClient
        self.device = device
    }
    
    func isSupported() async throws -> Bool {
        return device.supports(.artMode)
    }
    
    func listAvailable() async throws -> [ArtPiece] {
        guard try await isSupported() else {
            throw TVError.artModeNotSupported
        }
        return []
    }
    
    func current() async throws -> ArtPiece? {
        guard try await isSupported() else {
            throw TVError.artModeNotSupported
        }
        return nil
    }
    
    func select(artId: String) async throws {
        guard try await isSupported() else {
            throw TVError.artModeNotSupported
        }
    }
    
    func upload(imageData: Data, title: String, matteStyle: MatteStyle = .none) async throws -> String {
        guard try await isSupported() else {
            throw TVError.artModeNotSupported
        }
        throw TVError.unsupportedOperation(operation: "upload")
    }
    
    func delete(artId: String) async throws {
        guard try await isSupported() else {
            throw TVError.artModeNotSupported
        }
    }
    
    func deleteMultiple(artIds: [String]) async throws {
        guard try await isSupported() else {
            throw TVError.artModeNotSupported
        }
    }
    
    func thumbnail(artId: String) async throws -> Data {
        guard try await isSupported() else {
            throw TVError.artModeNotSupported
        }
        return Data()
    }
    
    func isArtModeActive() async throws -> Bool {
        guard try await isSupported() else {
            throw TVError.artModeNotSupported
        }
        return false
    }
    
    func setArtMode(active: Bool) async throws {
        guard try await isSupported() else {
            throw TVError.artModeNotSupported
        }
    }
    
    func availableFilters() async throws -> [PhotoFilter] {
        guard try await isSupported() else {
            throw TVError.artModeNotSupported
        }
        return []
    }
    
    func applyFilter(_ filter: PhotoFilter, to artId: String) async throws {
        guard try await isSupported() else {
            throw TVError.artModeNotSupported
        }
    }
}
