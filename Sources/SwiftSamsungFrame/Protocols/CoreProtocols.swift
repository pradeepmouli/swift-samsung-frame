import Foundation

/// Protocol for TV client functionality
public protocol TVClientProtocol: Sendable {
    /// Current connection state
    var state: ConnectionState { get async }
    
    /// Connected TV device
    var device: TVDevice? { get }
    
    /// Remote control interface
    var remote: any RemoteControlProtocol { get }
    
    /// Application management interface
    var apps: any AppManagementProtocol { get }
    
    /// Art controller interface
    var art: any ArtControllerProtocol { get }
    
    /// Connects to the TV
    /// - Parameters:
    ///   - device: TV device to connect to
    ///   - delegate: Optional delegate for connection events
    /// - Throws: TVError if connection fails
    func connect(to device: TVDevice, delegate: (any TVClientDelegate)?) async throws
    
    /// Disconnects from the TV
    func disconnect() async
    
    /// Retrieves device information
    /// - Returns: Dictionary of device info
    func deviceInfo() async throws -> [String: Any]
}

/// Protocol for remote control functionality
public protocol RemoteControlProtocol: Sendable {
    /// Sends a single key command
    /// - Parameter keyCode: Key code to send
    /// - Throws: TVError if command fails
    func sendKey(_ keyCode: KeyCode) async throws
    
    /// Sends multiple keys with delay between them
    /// - Parameters:
    ///   - keyCodes: Array of key codes to send
    ///   - delay: Delay between keys in milliseconds (default: 300)
    /// - Throws: TVError if command fails
    func sendKeys(_ keyCodes: [KeyCode], delay: Int) async throws
    
    /// Sends power toggle command
    func power() async throws
    
    /// Increases volume
    /// - Parameter steps: Number of steps (default: 1)
    func volumeUp(steps: Int) async throws
    
    /// Decreases volume
    /// - Parameter steps: Number of steps (default: 1)
    func volumeDown(steps: Int) async throws
    
    /// Toggles mute
    func mute() async throws
    
    /// Navigates in a direction
    /// - Parameter direction: Navigation direction
    func navigate(_ direction: NavigationDirection) async throws
    
    /// Sends enter/select command
    func enter() async throws
    
    /// Sends back command
    func back() async throws
    
    /// Sends home command
    func home() async throws
}

/// Protocol for application management
public protocol AppManagementProtocol: Sendable {
    /// Lists installed applications
    /// - Returns: Array of installed apps
    func list() async throws -> [TVApp]
    
    /// Launches an application
    /// - Parameter appId: Application ID
    func launch(appId: String) async throws
    
    /// Closes a running application
    /// - Parameter appId: Application ID
    func close(appId: String) async throws
    
    /// Gets application status
    /// - Parameter appId: Application ID
    /// - Returns: Application status
    func status(appId: String) async throws -> AppStatus
    
    /// Installs an application (if supported)
    /// - Parameter appId: Application ID
    func install(appId: String) async throws
}

/// Protocol for art mode control
public protocol ArtControllerProtocol: Sendable {
    /// Checks if art mode is supported
    /// - Returns: True if art mode is supported
    func isSupported() async throws -> Bool
    
    /// Lists available art pieces
    /// - Returns: Array of art pieces
    func listAvailable() async throws -> [ArtPiece]
    
    /// Gets currently displayed art
    /// - Returns: Current art piece
    func current() async throws -> ArtPiece?
    
    /// Selects an art piece to display
    /// - Parameter artId: Art ID
    func select(artId: String) async throws
    
    /// Uploads a custom image
    /// - Parameters:
    ///   - imageData: Image data
    ///   - title: Image title
    ///   - matteStyle: Matte style (default: none)
    /// - Returns: ID of uploaded art
    func upload(imageData: Data, title: String, matteStyle: MatteStyle) async throws -> String
    
    /// Deletes an art piece
    /// - Parameter artId: Art ID
    func delete(artId: String) async throws
    
    /// Deletes multiple art pieces
    /// - Parameter artIds: Array of art IDs
    func deleteMultiple(artIds: [String]) async throws
    
    /// Gets thumbnail for an art piece
    /// - Parameter artId: Art ID
    /// - Returns: Thumbnail image data
    func thumbnail(artId: String) async throws -> Data
    
    /// Checks if art mode is currently active
    /// - Returns: True if art mode is active
    func isArtModeActive() async throws -> Bool
    
    /// Sets art mode on or off
    /// - Parameter active: True to activate, false to deactivate
    func setArtMode(active: Bool) async throws
    
    /// Lists available photo filters
    /// - Returns: Array of available filters
    func availableFilters() async throws -> [PhotoFilter]
    
    /// Applies a filter to an art piece
    /// - Parameters:
    ///   - filter: Filter to apply
    ///   - artId: Art ID
    func applyFilter(_ filter: PhotoFilter, to artId: String) async throws
}

/// Protocol for device discovery
public protocol DiscoveryServiceProtocol: Sendable {
    /// Discovers TVs on the network
    /// - Returns: AsyncStream of discovery results
    func discover() -> AsyncStream<DiscoveryResult>
    
    /// Finds a TV at a specific IP address
    /// - Parameter ipAddress: IP address to check
    /// - Returns: Discovery result if TV is found
    func find(at ipAddress: String) async throws -> DiscoveryResult?
    
    /// Cancels ongoing discovery
    func cancel() async
}

/// Protocol for token storage
public protocol TokenStorageProtocol: Sendable {
    /// Saves an authentication token
    /// - Parameters:
    ///   - token: Token to save
    ///   - deviceId: Device ID
    /// - Returns: True if successful
    func saveToken(_ token: AuthenticationToken, for deviceId: String) async -> Bool
    
    /// Loads an authentication token
    /// - Parameter deviceId: Device ID
    /// - Returns: Token if found
    func loadToken(for deviceId: String) async -> AuthenticationToken?
    
    /// Deletes an authentication token
    /// - Parameter deviceId: Device ID
    /// - Returns: True if successful
    func deleteToken(for deviceId: String) async -> Bool
}

/// Delegate protocol for TV client events
public protocol TVClientDelegate: Sendable, AnyObject {
    /// Called when connection state changes
    /// - Parameter state: New connection state
    func tvClient(didChangeState state: ConnectionState) async
    
    /// Called when an error occurs
    /// - Parameter error: The error that occurred
    func tvClient(didEncounterError error: TVError) async
    
    /// Called when pairing is required
    /// - Returns: True if user approves pairing
    func tvClientRequiresPairing() async -> Bool
}
