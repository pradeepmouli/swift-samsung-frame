# SwiftSamsungFrame

A Swift 6 library for controlling Samsung Smart TVs and Frame TVs using WebSocket and REST APIs.

## Features

- ✅ **Swift 6** with strict concurrency enabled
- ✅ **Cross-platform support** (macOS 15+, iOS 18+, tvOS 18+, watchOS 11+)
- ✅ **Type-safe** async/await API
- ✅ **Secure connection** management with automatic reconnection
- ✅ **Token-based authentication** with Keychain storage
- 🚧 **Remote control** (basic implementation complete)
- 🚧 **Application management** (API defined)
- 🚧 **Art Mode control** for Frame TVs (API defined)
- 🚧 **Device discovery** (API defined)

## Requirements

- Swift 6.2 or later
- macOS 15+, iOS 18+, tvOS 18+, or watchOS 11+

## Installation

Add SwiftSamsungFrame to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/pradeepmouli/swift-samsung-frame.git", from: "0.1.0")
]
```

## Quick Start

### Basic Connection

```swift
import SwiftSamsungFrame

// Create a TV device
let device = TVDevice(
    id: "my-samsung-tv",
    ipAddress: "192.168.1.100",
    name: "Living Room TV"
)

// Create client
let client = TVClient()

// Connect to TV (pairing prompt will appear on TV first time)
try await client.connect(to: device)

// Send a remote control command
try await client.remote.sendKey(.power)
try await client.remote.volumeUp()
try await client.remote.navigate(.up)
try await client.remote.enter()

// Disconnect when done
await client.disconnect()
```

### Using Delegate for Connection Events

```swift
class MyTVDelegate: TVClientDelegate {
    func tvClient(didChangeState state: ConnectionState) async {
        print("Connection state changed: \(state)")
    }
    
    func tvClient(didEncounterError error: TVError) async {
        print("Error: \(error)")
    }
    
    func tvClientRequiresPairing() async -> Bool {
        print("TV requires pairing - approve on TV screen")
        return true  // User confirms pairing
    }
}

let delegate = MyTVDelegate()
try await client.connect(to: device, delegate: delegate)
```

### Remote Control Operations

```swift
// Power control
try await client.remote.power()

// Volume control
try await client.remote.volumeUp(steps: 3)
try await client.remote.volumeDown(steps: 2)
try await client.remote.mute()

// Navigation
try await client.remote.navigate(.up)
try await client.remote.navigate(.down)
try await client.remote.navigate(.left)
try await client.remote.navigate(.right)
try await client.remote.enter()
try await client.remote.back()
try await client.remote.home()

// Send multiple keys with delay
try await client.remote.sendKeys([.down, .down, .enter], delay: 300)
```

### Retrieving Device Information

```swift
let info = try await client.deviceInfo()
print("Device info: \(info)")
```

## Architecture

The library is organized into the following components:

### Core Components

- **TVClient**: Main entry point for controlling TVs
- **WebSocketClient**: Actor-based WebSocket communication with automatic health checks
- **RESTClient**: HTTP REST API client for additional operations
- **ConnectionSession**: Manages connection state and authentication tokens

### Models

- **TVDevice**: Represents a Samsung TV with connection details
- **AuthenticationToken**: Secure token storage with Keychain support
- **ConnectionState**: Enum representing connection lifecycle states
- **TVError**: Comprehensive error types for all failure scenarios

### Protocols

- **TVClientProtocol**: Main TV client interface
- **RemoteControlProtocol**: Remote control operations
- **AppManagementProtocol**: App management operations (coming soon)
- **ArtControllerProtocol**: Frame TV art mode operations (coming soon)
- **DiscoveryServiceProtocol**: Network device discovery (coming soon)
- **TVClientDelegate**: Connection event notifications

## Implementation Status

### ✅ Complete (MVP)
- Project setup and configuration
- All foundational types and protocols
- WebSocket client with ping/pong health checks
- REST client with multipart upload support
- TVClient with connection management
- Authentication and token storage
- Reconnection with exponential backoff
- Basic remote control commands
- Comprehensive error handling
- Logging infrastructure

### 🚧 In Progress
- Full RemoteControl implementation with retry logic
- Application management
- Art Mode control for Frame TVs
- Device discovery (mDNS/SSDP)
- Comprehensive test suite
- Example applications
- DocC documentation

## Development

### Building

```bash
swift build
```

### Testing

```bash
swift test
```

### Linting

```bash
swiftlint
```

## Security

- Authentication tokens are securely stored in Keychain (on Apple platforms)
- WebSocket connections use WSS (WebSocket Secure)
- Self-signed certificates are accepted for local TV connections
- Token persistence allows seamless reconnection

## Platform Notes

- **Keychain**: Only available on Apple platforms. Token storage returns `false` on other platforms.
- **Logging**: Uses `os.Logger` on Apple platforms. Conditionally compiled out on other platforms.
- **URLSession**: Uses FoundationNetworking on Linux and non-Apple platforms.

## Contributing

Contributions are welcome! Please see CONTRIBUTING.md for guidelines.

## License

[Add your license information here]

## References

- Inspired by [samsung-tv-ws-api](https://github.com/xchwarze/samsung-tv-ws-api)
- [Samsung TV WebSocket API Documentation](https://github.com/Ape/samsungctl)

## Acknowledgments

This library implements the Samsung Smart TV WebSocket and REST APIs based on community reverse-engineering efforts.
