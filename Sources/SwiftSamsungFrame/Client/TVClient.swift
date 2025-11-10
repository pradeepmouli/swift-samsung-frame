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

// MARK: - AppManagement Implementation

actor AppManagement: AppManagementProtocol {
    private var webSocket: WebSocketClient?
    private var restClient: RESTClient?
    
    func setWebSocket(_ ws: WebSocketClient) {
        self.webSocket = ws
    }
    
    func setRESTClient(_ client: RESTClient?) {
        self.restClient = client
    }
    
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
    
    public func launch(_ appID: String) async throws {
        guard let webSocket else {
            throw TVError.connectionFailed(reason: "Not connected")
        }
        
        #if canImport(OSLog)
        Logger.commands.info("Launching app: \(appID)")
        #endif
        
        let message = AppListMessage.launchApp(appID: appID)
        let data = try JSONEncoder().encode(message)
        try await webSocket.send(data)
    }
    
    public func close(_ appID: String) async throws {
        guard let restClient else {
            throw TVError.connectionFailed(reason: "REST client not available")
        }
        
        #if canImport(OSLog)
        Logger.commands.info("Closing app via REST: \(appID)")
        #endif
        
        try await restClient.closeApp(appID: appID)
    }
    
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

actor ArtController: ArtControllerProtocol {
    private var webSocket: WebSocketClient?
    private var restClient: RESTClient?
    private var artUUID: String?
    
    func setWebSocket(_ ws: WebSocketClient) {
        self.webSocket = ws
    }
    
    func setRESTClient(_ client: RESTClient?) {
        self.restClient = client
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
    
    public func listAvailable() async throws -> [ArtPiece] {
        #if canImport(OSLog)
        Logger.commands.debug("Requesting art list")
        #endif
        
        try await sendArtRequest([
            "request": "get_content_list",
            "category": NSNull()
        ])
        
        // Note: Full implementation would wait for and parse response
        // This requires WebSocket response handling
        return []
    }
    
    public func current() async throws -> ArtPiece {
        #if canImport(OSLog)
        Logger.commands.debug("Requesting current artwork")
        #endif
        
        try await sendArtRequest([
            "request": "get_current_artwork"
        ])
        
        // Note: Full implementation would parse response
        throw TVError.artModeNotSupported
    }
    
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
    
    public func upload(
        _ imageData: Data,
        type imageType: ImageType,
        matte: MatteStyle? = nil
    ) async throws -> String {
        #if canImport(OSLog)
        Logger.commands.info("Uploading image via WebSocket D2D transfer")
        #endif
        
        let fileType = imageType == .jpeg ? "jpg" : "png"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        let dateString = dateFormatter.string(from: Date())
        
        let connectionID = D2DSocketClient.generateConnectionID()
        
        try await sendArtRequest([
            "request": "send_image",
            "file_type": fileType,
            "request_id": getOrGenerateUUID(),
            "conn_info": [
                "d2d_mode": "socket",
                "connection_id": connectionID,
                "id": getOrGenerateUUID()
            ],
            "image_date": dateString,
            "matte_id": matte?.rawValue ?? "none",
            "portrait_matte_id": matte?.rawValue ?? "none",
            "file_size": imageData.count
        ])
        
        // Note: Full implementation would:
        // 1. Wait for ready_to_use response with connection info
        // 2. Connect to D2D socket
        // 3. Send header + image data
        // 4. Wait for image_added confirmation
        // 5. Return content_id
        
        throw TVError.commandFailed(
            code: 501,
            message: "Upload requires full D2D socket implementation"
        )
    }
    
    public func delete(_ artID: String) async throws {
        try await deleteMultiple([artID])
    }
    
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
    
    public func isArtModeActive() async throws -> Bool {
        #if canImport(OSLog)
        Logger.commands.debug("Checking art mode status")
        #endif
        
        try await sendArtRequest([
            "request": "get_artmode_status"
        ])
        
        // Note: Full implementation would parse response
        return false
    }
    
    public func setArtMode(enabled: Bool) async throws {
        #if canImport(OSLog)
        Logger.commands.info("Setting art mode: \(enabled)")
        #endif
        
        try await sendArtRequest([
            "request": "set_artmode_status",
            "value": enabled ? "on" : "off"
        ])
    }
    
    public func availableFilters() async throws -> [PhotoFilter] {
        #if canImport(OSLog)
        Logger.commands.debug("Requesting photo filter list")
        #endif
        
        try await sendArtRequest([
            "request": "get_photo_filter_list"
        ])
        
        // Note: Full implementation would parse response
        return []
    }
    
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
