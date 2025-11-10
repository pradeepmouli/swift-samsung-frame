# API Contracts: Samsung TV Client Library

**Date**: 2025-11-09
**Feature**: 001-samsung-tv-client

## Overview

This document specifies the API contracts for the Samsung TV Client library. All APIs use async/await patterns and follow Swift 6 concurrency guidelines.

## Public API Surface

### TVClient

Main entry point for Samsung TV interaction.

```swift
public protocol TVClientProtocol: Sendable {
    /// Connect to a Samsung TV
    /// - Parameters:
    ///   - host: TV IP address or hostname
    ///   - tokenStorage: Optional token storage for persistence
    /// - Returns: Connected client instance
    /// - Throws: TVError.connectionFailed, TVError.authenticationRequired
    func connect(
        to host: String,
        port: Int = 8001,
        tokenStorage: TokenStorageProtocol? = nil
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
    var remote: RemoteControlProtocol { get }
    
    /// App management interface
    var apps: AppManagementProtocol { get }
    
    /// Art mode interface (Frame TVs only)
    var art: ArtControllerProtocol { get }
}
```

**Usage Example**:
```swift
let client = TVClient()
try await client.connect(to: "192.168.1.100")
let info = try await client.deviceInfo()
print("Connected to \(info.name)")
```

---

### RemoteControlProtocol

Interface for sending remote control commands.

```swift
public protocol RemoteControlProtocol: Sendable {
    /// Send a specific key command
    /// - Parameter key: Key code to send
    /// - Throws: TVError.commandFailed, TVError.timeout
    func sendKey(_ key: KeyCode) async throws
    
    /// Send multiple keys in sequence
    /// - Parameter keys: Array of key codes
    /// - Parameter delay: Delay between keys (default: 100ms)
    /// - Throws: TVError.commandFailed
    func sendKeys(_ keys: [KeyCode], delay: Duration = .milliseconds(100)) async throws
    
    /// Toggle power state
    /// - Throws: TVError.commandFailed
    func power() async throws
    
    /// Increase volume
    /// - Parameter steps: Number of volume increments (default: 1)
    /// - Throws: TVError.commandFailed
    func volumeUp(steps: Int = 1) async throws
    
    /// Decrease volume
    /// - Parameter steps: Number of volume decrements (default: 1)
    /// - Throws: TVError.commandFailed
    func volumeDown(steps: Int = 1) async throws
    
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
```

**Usage Example**:
```swift
let remote = client.remote
try await remote.power()
try await remote.navigate(.down)
try await remote.enter()
```

---

### AppManagementProtocol

Interface for managing TV applications.

```swift
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
    /// - Throws: TVError.commandFailed, TVError.unsupportedOperation
    func install(_ appID: String) async throws
}
```

**Usage Example**:
```swift
let apps = try await client.apps.list()
let netflix = apps.first { $0.name == "Netflix" }
if let netflix {
    try await client.apps.launch(netflix.id)
}
```

---

### ArtControllerProtocol

Interface for Frame TV Art Mode features.

```swift
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
    func select(_ artID: String, show: Bool = true) async throws
    
    /// Upload custom image
    /// - Parameters:
    ///   - imageData: Image data (JPEG or PNG)
    ///   - imageType: Image format
    ///   - matte: Optional matte style
    /// - Returns: Uploaded art ID
    /// - Throws: TVError.uploadFailed, TVError.invalidImageFormat
    func upload(
        _ imageData: Data,
        type imageType: ImageType,
        matte: MatteStyle? = nil
    ) async throws -> String
    
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
    ///   - artID: Art piece identifier
    ///   - filter: Filter to apply
    /// - Throws: TVError.commandFailed
    func applyFilter(_ filter: PhotoFilter, to artID: String) async throws
}
```

**Usage Example**:
```swift
let art = client.art
if try await art.isSupported() {
    let available = try await art.listAvailable()
    try await art.select(available.first!.id)
    try await art.setArtMode(enabled: true)
}
```

---

### DiscoveryServiceProtocol

Interface for discovering Samsung TVs on the network.

```swift
public protocol DiscoveryServiceProtocol: Sendable {
    /// Discover TVs on local network
    /// - Parameter timeout: Discovery timeout duration
    /// - Returns: AsyncStream of discovered devices
    func discover(timeout: Duration = .seconds(10)) -> AsyncStream<DiscoveryResult>
    
    /// Cancel ongoing discovery
    func cancel()
    
    /// Quick scan for specific TV
    /// - Parameter host: Known IP address to check
    /// - Returns: Discovery result if TV found
    /// - Throws: TVError.deviceNotFound
    func find(at host: String) async throws -> DiscoveryResult
}
```

**Usage Example**:
```swift
let discovery = DiscoveryService()
for await result in discovery.discover() {
    print("Found TV: \(result.device.name) at \(result.device.host)")
}
```

---

### TokenStorageProtocol

Interface for storing authentication tokens securely.

```swift
public protocol TokenStorageProtocol: Sendable {
    /// Save authentication token
    /// - Parameters:
    ///   - token: Token to save
    ///   - deviceID: Associated device identifier
    /// - Throws: TVError.storageFailed
    func save(_ token: AuthenticationToken, for deviceID: String) async throws
    
    /// Retrieve authentication token
    /// - Parameter deviceID: Device identifier
    /// - Returns: Stored token if available
    /// - Throws: TVError.storageFailed
    func retrieve(for deviceID: String) async throws -> AuthenticationToken?
    
    /// Delete authentication token
    /// - Parameter deviceID: Device identifier
    /// - Throws: TVError.storageFailed
    func delete(for deviceID: String) async throws
    
    /// Clear all stored tokens
    /// - Throws: TVError.storageFailed
    func clearAll() async throws
}
```

**Default Implementation**: `KeychainTokenStorage`

---

## Supporting Types

### NavigationDirection

```swift
public enum NavigationDirection: Sendable {
    case up
    case down
    case left
    case right
}
```

### Duration Extensions

```swift
extension Duration {
    public static func milliseconds(_ value: Int) -> Duration
    public static func seconds(_ value: Int) -> Duration
}
```

## Error Handling

All async methods can throw `TVError`. Clients should handle errors appropriately:

```swift
do {
    try await client.connect(to: "192.168.1.100")
} catch TVError.authenticationRequired {
    // Prompt user to approve on TV
    print("Please approve the connection on your TV")
} catch TVError.connectionFailed(let reason) {
    print("Connection failed: \(reason)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Callback/Delegate Pattern (Optional)

For connection state changes:

```swift
public protocol TVClientDelegate: Sendable {
    /// Called when connection state changes
    func client(_ client: TVClient, didChangeState state: ConnectionState) async
    
    /// Called when authentication is required
    func clientRequiresAuthentication(_ client: TVClient) async
    
    /// Called when error occurs
    func client(_ client: TVClient, didEncounterError error: TVError) async
}
```

## Testing Helpers

### MockTVClient

```swift
public final class MockTVClient: TVClientProtocol {
    public var mockState: ConnectionState = .disconnected
    public var mockDeviceInfo: TVDevice = .example
    public var shouldThrowOnConnect: Bool = false
    
    // ... implement all protocol methods for testing
}
```

## Initialization Examples

### Basic Connection

```swift
let client = TVClient()
try await client.connect(to: "192.168.1.100")
```

### With Token Persistence

```swift
let storage = KeychainTokenStorage()
let client = TVClient()
try await client.connect(to: "192.168.1.100", tokenStorage: storage)
```

### With Custom Port

```swift
try await client.connect(to: "192.168.1.100", port: 8002)
```

### With Delegate

```swift
let client = TVClient()
client.delegate = self
try await client.connect(to: "192.168.1.100")
```

## Platform-Specific Notes

### macOS

- Full support for all features
- Keychain access requires entitlements

### iOS/tvOS

- Full support for all features
- Background network access requires capabilities

### watchOS

- Limited to basic remote control (no art upload due to memory constraints)
- Discovery may be slower on cellular watches

## Performance Guarantees

- Command execution: <500ms from send to acknowledgment
- Connection establishment: <3s on local network
- Device discovery: Complete within 10s timeout
- Image upload: <5s for images under 5MB
- Connection health check: Every 30s with <100ms ping

## Versioning

This API follows semantic versioning:
- **Major**: Breaking changes to public API
- **Minor**: New features, backward compatible
- **Patch**: Bug fixes, no API changes

Current version: **0.1.0** (initial development)
