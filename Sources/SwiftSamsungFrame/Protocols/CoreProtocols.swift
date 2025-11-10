// CoreProtocols - Core protocol definitions for Samsung TV Client
// Defines interfaces for all major components

import Foundation

/// Main entry point for Samsung TV interaction
public protocol TVClientProtocol: Sendable {
    /// Connect to a Samsung TV
    /// - Parameters:
    ///   - host: TV IP address or hostname
    ///   - port: WebSocket port (default: 8001)
    ///   - tokenStorage: Optional token storage for persistence
    /// - Returns: Connected session instance
    /// - Throws: TVError.connectionFailed, TVError.authenticationRequired
    func connect(
        to host: String,
        port: Int,
        tokenStorage: (any TokenStorageProtocol)?
    ) async throws -> ConnectionSession
    
    /// Disconnect from the TV
    func disconnect() async
    
    /// Get current connection state
    var state: ConnectionState { get async }
    
    /// Get device information
    /// - Returns: TV device details
    /// - Throws: TVError.networkUnreachable, TVError.invalidResponse
    func deviceInfo() async throws -> TVDevice
    
    /// Remote control interface
    var remote: any RemoteControlProtocol { get }
    
    /// App management interface
    var apps: any AppManagementProtocol { get }
    
    /// Art mode interface (Frame TVs only)
    var art: any ArtControllerProtocol { get }
}

/// Interface for sending remote control commands
public protocol RemoteControlProtocol: Sendable {
    /// Send a specific key command
    /// - Parameter key: Key code to send
    /// - Throws: TVError.commandFailed, TVError.timeout
    func sendKey(_ key: KeyCode) async throws
    
    /// Send multiple keys in sequence
    /// - Parameters:
    ///   - keys: Array of key codes
    ///   - delay: Delay between keys (default: 100ms)
    /// - Throws: TVError.commandFailed
    func sendKeys(_ keys: [KeyCode], delay: Duration) async throws
    
    /// Toggle power state
    /// - Throws: TVError.commandFailed
    func power() async throws
    
    /// Increase volume
    /// - Parameter steps: Number of volume increments
    /// - Throws: TVError.commandFailed
    func volumeUp(steps: Int) async throws
    
    /// Decrease volume
    /// - Parameter steps: Number of volume decrements
    /// - Throws: TVError.commandFailed
    func volumeDown(steps: Int) async throws
    
    /// Toggle mute
    /// - Throws: TVError.commandFailed
    func mute() async throws
    
    /// Navigate in direction
    /// - Parameter direction: Navigation direction
    /// - Throws: TVError.commandFailed
    func navigate(_ direction: NavigationDirection) async throws
    
    /// Press enter/select
    /// - Throws: TVError.commandFailed
    func enter() async throws
    
    /// Press back button
    /// - Throws: TVError.commandFailed
    func back() async throws
    
    /// Go to home screen
    /// - Throws: TVError.commandFailed
    func home() async throws
}

/// Interface for managing TV applications
public protocol AppManagementProtocol: Sendable {
    /// List all installed applications
    /// - Returns: Array of installed apps
    /// - Throws: TVError.networkUnreachable, TVError.invalidResponse
    func list() async throws -> [TVApp]
    
    /// Launch an application
    /// - Parameter appID: Unique app identifier
    /// - Throws: TVError.commandFailed
    func launch(_ appID: String) async throws
    
    /// Close a running application
    /// - Parameter appID: Unique app identifier
    /// - Throws: TVError.commandFailed
    func close(_ appID: String) async throws
    
    /// Get application status
    /// - Parameter appID: Unique app identifier
    /// - Returns: Current app status
    /// - Throws: TVError.invalidResponse
    func status(of appID: String) async throws -> AppStatus
    
    /// Install app from store (if supported)
    /// - Parameter appID: App identifier from store
    /// - Throws: TVError.commandFailed
    func install(_ appID: String) async throws
}

/// Interface for Frame TV Art Mode features
public protocol ArtControllerProtocol: Sendable {
    /// Check if Art Mode is supported
    /// - Returns: True if TV supports Art Mode
    /// - Throws: TVError.networkUnreachable
    func isSupported() async throws -> Bool
    
    /// List available art pieces
    /// - Returns: Array of available art
    /// - Throws: TVError.artModeNotSupported, TVError.invalidResponse
    func listAvailable() async throws -> [ArtPiece]
    
    /// Get currently selected art
    /// - Returns: Current art piece
    /// - Throws: TVError.artModeNotSupported, TVError.invalidResponse
    func current() async throws -> ArtPiece
    
    /// Select an art piece to display
    /// - Parameters:
    ///   - artID: Unique art identifier
    ///   - show: Whether to immediately show (enter art mode)
    /// - Throws: TVError.commandFailed, TVError.deviceNotFound
    func select(_ artID: String, show: Bool) async throws
    
    /// Upload custom image
    /// - Parameters:
    ///   - imageData: Image data (JPEG or PNG)
    ///   - imageType: Image format
    ///   - matte: Optional matte style
    /// - Returns: Uploaded art ID
    /// - Throws: TVError.uploadFailed, TVError.invalidImageFormat
    func upload(_ imageData: Data, type imageType: ImageType, matte: MatteStyle?) async throws -> String
    
    /// Delete uploaded art
    /// - Parameter artID: Art piece to delete
    /// - Throws: TVError.commandFailed
    func delete(_ artID: String) async throws
    
    /// Delete multiple uploaded art pieces
    /// - Parameter artIDs: Array of art IDs to delete
    /// - Throws: TVError.commandFailed
    func deleteMultiple(_ artIDs: [String]) async throws
    
    /// Get thumbnail for art piece
    /// - Parameter artID: Art identifier
    /// - Returns: Thumbnail image data (JPEG)
    /// - Throws: TVError.invalidResponse
    func thumbnail(for artID: String) async throws -> Data
    
    /// Check if Art Mode is currently active
    /// - Returns: True if in Art Mode
    /// - Throws: TVError.artModeNotSupported
    func isArtModeActive() async throws -> Bool
    
    /// Toggle Art Mode on or off
    /// - Parameter enabled: True to enable, false to disable
    /// - Throws: TVError.commandFailed
    func setArtMode(enabled: Bool) async throws
    
    /// List available photo filters
    /// - Returns: Array of available filters
    /// - Throws: TVError.artModeNotSupported
    func availableFilters() async throws -> [PhotoFilter]
    
    /// Apply photo filter to art
    /// - Parameters:
    ///   - filter: Filter to apply
    ///   - artID: Art piece identifier
    /// - Throws: TVError.commandFailed
    func applyFilter(_ filter: PhotoFilter, to artID: String) async throws
}

/// Interface for discovering Samsung TVs on the network
public protocol DiscoveryServiceProtocol: Sendable {
    /// Discover TVs on local network
    /// - Parameter timeout: Discovery timeout duration
    /// - Returns: AsyncStream of discovered devices
    func discover(timeout: Duration) -> AsyncStream<DiscoveryResult>
    
    /// Cancel ongoing discovery
    func cancel()
    
    /// Quick scan for specific TV
    /// - Parameter host: Known IP address to check
    /// - Returns: Discovery result if TV found
    /// - Throws: TVError.deviceNotFound
    func find(at host: String) async throws -> DiscoveryResult
}

/// Interface for storing authentication tokens securely
public protocol TokenStorageProtocol: Sendable {
    /// Save authentication token
    /// - Parameters:
    ///   - token: Token to save
    ///   - deviceID: Associated device identifier
    /// - Throws: TVError
    func save(_ token: AuthenticationToken, for deviceID: String) async throws
    
    /// Retrieve authentication token
    /// - Parameter deviceID: Device identifier
    /// - Returns: Stored token if available
    /// - Throws: TVError
    func retrieve(for deviceID: String) async throws -> AuthenticationToken?
    
    /// Delete authentication token
    /// - Parameter deviceID: Device identifier
    /// - Throws: TVError
    func delete(for deviceID: String) async throws
    
    /// Clear all stored tokens
    /// - Throws: TVError
    func clearAll() async throws
}

/// Delegate for TV client state changes
public protocol TVClientDelegate: Sendable {
    /// Called when connection state changes
    func client(_ client: any TVClientProtocol, didChangeState state: ConnectionState) async
    
    /// Called when authentication is required
    func clientRequiresAuthentication(_ client: any TVClientProtocol) async
    
    /// Called when error occurs
    func client(_ client: any TVClientProtocol, didEncounterError error: TVError) async
}
