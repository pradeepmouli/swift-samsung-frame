# SwiftSamsungFrame

A Swift 6 library for controlling Samsung TVs (2016+), providing remote control, application management, and Art Mode features for Frame TVs.

## Features

- ✅ Swift 6 with strict concurrency enabled
- ✅ Cross-platform support (macOS, iOS, tvOS, watchOS)
- ✅ Swift Package Manager integration
- ✅ WebSocket-based real-time communication
- ✅ REST API for device management
- ✅ Actor-based thread-safe connection management
- ✅ Keychain-based secure token storage
- 🚧 Remote control commands (MVP implemented)
- 🚧 Application management (stub implementation)
- 🚧 Art Mode for Frame TVs (stub implementation)
- 🚧 Network device discovery (planned)

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

**Current Version**: 0.1.0-alpha (MVP)

### Completed
- ✅ Core data models and protocols
- ✅ WebSocket client with TLS support
- ✅ REST API client
- ✅ TVClient with connection management
- ✅ Basic remote control commands
- ✅ Keychain token storage

### In Progress
- 🚧 Full application management
- 🚧 Art Mode control for Frame TVs
- 🚧 Network device discovery (mDNS/SSDP)
- 🚧 Comprehensive test coverage

### Planned
- 📋 Advanced connection features (reconnection, health checks)
- 📋 Complete documentation
- 📋 Example applications

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
- [Samsung Smart TV Remote Control Protocol](https://github.com/Ape/samsungctl)

