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
/// try await client.apps.launch("111299001912") // YouTube
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
        
        try await sendArtRequest([
            "request": "get_content_list",
            "category": NSNull()
        ])
        
        // Note: Full implementation would wait for and parse response
        // This requires WebSocket response handling
        return []
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
        
        try await sendArtRequest([
            "request": "get_current_artwork"
        ])
        
        // Note: Full implementation would parse response
        throw TVError.artModeNotSupported
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
    /// - Throws: `TVError.invalidImageFormat` if image format is invalid or too large
    /// - Throws: `TVError.uploadFailed` if upload fails
    /// - Throws: `TVError.commandFailed` if D2D socket implementation is not complete
    ///
    /// Note: Full upload requires D2D socket implementation.
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
        
        try await sendArtRequest([
            "request": "get_artmode_status"
        ])
        
        // Note: Full implementation would parse response
        return false
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
        
        try await sendArtRequest([
            "request": "get_photo_filter_list"
        ])
        
        // Note: Full implementation would parse response
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
