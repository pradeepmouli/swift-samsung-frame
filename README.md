# SwiftSamsungFrame

A Swift 6 library for controlling Samsung TVs (2016+), providing remote control, application management, and Art Mode features for Frame TVs.

## Features

- ✅ Swift 6 with strict concurrency enabled
- ✅ Cross-platform support (macOS, iOS, tvOS, watchOS, Linux)
- ✅ Swift Package Manager integration
- ✅ WebSocket-based real-time communication
- ✅ REST API for device management
- ✅ Actor-based thread-safe connection management
- ✅ Keychain-based secure token storage
- ✅ Remote control commands (MVP implemented)
- ✅ Application management (WebSocket + REST API)
- ✅ Art Mode for Frame TVs (WebSocket-based, D2D transfer structure)
- ✅ Network device discovery (manual lookup implemented)
- 🚧 Full D2D socket implementation (requires platform-specific code)
- 🚧 mDNS/SSDP discovery (stub implementation)
- 🚧 Advanced connection features (health checks, auto-reconnect)

## Requirements

- Swift 6.2 or later
- macOS 15+, iOS 18+, tvOS 18+, or watchOS 11+
- Samsung TV (2016+ models with Tizen OS)

## Installation

Add SwiftSamsungFrame to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/swift-samsung-frame.git", from: "0.1.0")
]
```

## Usage

### Basic Connection and Remote Control

```swift
import SwiftSamsungFrame

// Create client instance
let client = TVClient()

// Connect to TV
do {
    try await client.connect(to: "192.168.1.100")
    print("Connected to TV")
    
    // Get device information
    let device = try await client.deviceInfo()
    print("Connected to: \(device.name)")
    
    // Send remote control commands
    try await client.remote.power()
    try await client.remote.volumeUp(steps: 5)
    try await client.remote.navigate(.down)
    try await client.remote.enter()
    
    // Disconnect when done
    await client.disconnect()
} catch {
    print("Error: \(error.localizedDescription)")
}
```

### With Token Persistence

```swift
// Use Keychain for storing auth tokens
let storage = KeychainTokenStorage()
let client = TVClient()

try await client.connect(
    to: "192.168.1.100",
    tokenStorage: storage
)

// Token will be automatically saved and reused on reconnection
```

### Remote Control Commands

```swift
// Basic commands
try await client.remote.power()
try await client.remote.volumeUp()
try await client.remote.volumeDown()
try await client.remote.mute()

// Navigation
try await client.remote.navigate(.up)
try await client.remote.navigate(.down)
try await client.remote.navigate(.left)
try await client.remote.navigate(.right)
try await client.remote.enter()
try await client.remote.back()
try await client.remote.home()

// Send multiple keys in sequence
try await client.remote.sendKeys([.down, .down, .enter], delay: .milliseconds(200))
```

### Application Management

```swift
// Launch an app
try await client.apps.launch("111299001912") // YouTube app ID

// Get app status
let status = try await client.apps.status(of: "111299001912")
print("App is \(status)")

// Close an app
try await client.apps.close("111299001912")

// List installed apps (sends request via WebSocket)
let apps = try await client.apps.list()

// Install an app from store
try await client.apps.install("appIdFromStore")
```

### Art Mode (Frame TVs)

```swift
// Check if Art Mode is supported
let isSupported = try await client.art.isSupported()

// Select an art piece
try await client.art.select("contentId", show: true)

// Enable/disable Art Mode
try await client.art.setArtMode(enabled: true)

// Delete art pieces
try await client.art.delete("contentId")
try await client.art.deleteMultiple(["id1", "id2"])

// Apply photo filters
try await client.art.applyFilter(.watercolor, to: "contentId")

// Get available filters
let filters = try await client.art.availableFilters()
```

### Device Discovery

```swift
// Manual lookup of a known TV
let discovery = DiscoveryService()
let result = try await discovery.find(at: "192.168.1.100")
print("Found: \(result.device.name)")

// Discover TVs on network (stub - requires platform-specific implementation)
for await result in discovery.discover(timeout: .seconds(5)) {
    print("Discovered: \(result.device.name) at \(result.device.host)")
}
```

## Architecture

The library is organized into modular components:

- **Models**: Core data structures (TVDevice, TVApp, ArtPiece, etc.)
- **Protocols**: Protocol-oriented interfaces for all major components
- **Client**: Main TVClient and connection management
- **Networking**: WebSocket and REST API clients
- **Commands**: Remote control command implementations
- **Extensions**: Utility extensions (Logger, Duration)

All components follow Swift 6 strict concurrency requirements using actors and Sendable types.

## Development Status

**Current Version**: 0.2.0-alpha

### Completed
- ✅ Core data models and protocols
- ✅ WebSocket client with TLS support
- ✅ REST API client
- ✅ TVClient with connection management
- ✅ Remote control commands (full implementation)
- ✅ Keychain token storage
- ✅ Application management (WebSocket + REST)
- ✅ Art Mode WebSocket protocol implementation
- ✅ Device discovery (manual lookup)

### In Progress
- 🚧 D2D socket implementation for art upload/download
- 🚧 mDNS/SSDP network discovery
- 🚧 WebSocket response parsing for art and app lists

### Planned
- 📋 Advanced connection features (health checks, auto-reconnect)
- 📋 Complete documentation
- 📋 Example applications
- 📋 Comprehensive integration tests

## Development

### Building

```bash
swift build
```

### Testing

```bash
swift test
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

[Add your license information here]

## References

- [Samsung TV WebSocket API Documentation](https://github.com/xchwarze/samsung-tv-ws-api)
- [Samsung TV Art Updates Branch](https://github.com/xchwarze/samsung-tv-ws-api/tree/art-updates) - Reference for Art Mode implementation
- [Samsung Smart TV Remote Control Protocol](https://github.com/Ape/samsungctl)

