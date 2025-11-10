# Samsung TV Client - Quick Start Guide

**Date**: 2025-11-09
**Feature**: 001-samsung-tv-client
**Target Audience**: Developers using SwiftSamsungFrame library

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftSamsungFrame.git", from: "0.1.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter repository URL: `https://github.com/yourusername/SwiftSamsungFrame`
3. Select version: `0.1.0` or later

### Platform Requirements

- macOS 15.0+
- iOS 18.0+
- tvOS 18.0+
- watchOS 11.0+
- Swift 6.2+

## Basic Setup

### Import the Framework

```swift
import SwiftSamsungFrame
```

### Create a Client

```swift
let client = TVClient()
```

## Quick Examples

### 1. Connect to Your TV

**First Time (with approval)**:

```swift
do {
    try await client.connect(to: "192.168.1.100")
    // TV will display approval prompt
    // User approves on TV screen
    // Connection established automatically
    print("Connected successfully!")
} catch TVError.authenticationRequired {
    print("Please approve the connection on your TV")
} catch {
    print("Connection failed: \(error)")
}
```

**Subsequent Connections (with token storage)**:

```swift
let storage = KeychainTokenStorage()
let client = TVClient()

try await client.connect(to: "192.168.1.100", tokenStorage: storage)
// Connects immediately without approval (token reused)
```

---

### 2. Get Device Information

```swift
let deviceInfo = try await client.deviceInfo()
print("TV Name: \(deviceInfo.name)")
print("Model: \(deviceInfo.modelName)")
print("Supports Art Mode: \(deviceInfo.features.contains(.artMode))")
```

---

### 3. Remote Control

**Power Control**:

```swift
// Toggle power
try await client.remote.power()

// Volume control
try await client.remote.volumeUp(steps: 3)
try await client.remote.volumeDown()
try await client.remote.mute()
```

**Navigation**:

```swift
// Navigate menu
try await client.remote.navigate(.down)
try await client.remote.navigate(.right)
try await client.remote.enter()

// Go back
try await client.remote.back()

// Home screen
try await client.remote.home()
```

**Send Custom Keys**:

```swift
// Single key
try await client.remote.sendKey(.menu)

// Multiple keys
try await client.remote.sendKeys([.down, .down, .enter], delay: .milliseconds(200))
```

---

### 4. Application Management

**List Installed Apps**:

```swift
let apps = try await client.apps.list()
for app in apps {
    print("\(app.name) - ID: \(app.id)")
}
```

**Launch an App**:

```swift
// Find Netflix
if let netflix = apps.first(where: { $0.name == "Netflix" }) {
    try await client.apps.launch(netflix.id)
    print("Netflix launched!")
}

// Or launch directly by ID
try await client.apps.launch("3201907018807") // Netflix ID
```

**Check App Status**:

```swift
let status = try await client.apps.status(of: "111299001912") // YouTube
print("YouTube is \(status)")
```

---

### 5. Art Mode (Frame TV Only)

**Check Support**:

```swift
guard try await client.art.isSupported() else {
    print("This TV doesn't support Art Mode")
    return
}
```

**Browse Available Art**:

```swift
let artPieces = try await client.art.listAvailable()
for art in artPieces {
    print("\(art.title) - Category: \(art.category)")
}
```

**Select and Display Art**:

```swift
if let firstArt = artPieces.first {
    // Select art and enter Art Mode
    try await client.art.select(firstArt.id, show: true)
    print("Now displaying: \(firstArt.title)")
}
```

**Upload Custom Image**:

```swift
// Load image from file
guard let imageData = try? Data(contentsOf: imageURL) else {
    print("Failed to load image")
    return
}

// Upload with optional matte
let artID = try await client.art.upload(
    imageData,
    type: .jpeg,
    matte: .modernGrey
)

print("Uploaded art ID: \(artID)")

// Display the uploaded art
try await client.art.select(artID, show: true)
```

**Toggle Art Mode**:

```swift
// Enable Art Mode
try await client.art.setArtMode(enabled: true)

// Check if active
let isActive = try await client.art.isArtModeActive()
print("Art Mode active: \(isActive)")

// Disable Art Mode
try await client.art.setArtMode(enabled: false)
```

**Apply Filters**:

```swift
let filters = try await client.art.availableFilters()
try await client.art.applyFilter(.grayscale, to: artID)
```

---

### 6. TV Discovery

**Discover TVs on Network**:

```swift
let discovery = DiscoveryService()

for await result in discovery.discover(timeout: .seconds(10)) {
    print("Found: \(result.device.name)")
    print("  IP: \(result.device.host)")
    print("  Model: \(result.device.modelName)")
    print("  Method: \(result.method)")
}
```

**Find Specific TV**:

```swift
do {
    let result = try await discovery.find(at: "192.168.1.100")
    print("TV found: \(result.device.name)")
} catch {
    print("TV not found at this address")
}
```

---

### 7. Connection State Monitoring

**Using Async Property**:

```swift
let state = await client.state
switch state {
case .connected:
    print("Ready to send commands")
case .connecting:
    print("Connecting...")
case .disconnected:
    print("Not connected")
case .authenticating:
    print("Waiting for TV approval")
}
```

**Using Delegate** (Optional):

```swift
class MyTVDelegate: TVClientDelegate {
    func client(_ client: TVClient, didChangeState state: ConnectionState) async {
        print("Connection state changed to: \(state)")
    }

    func clientRequiresAuthentication(_ client: TVClient) async {
        print("Please approve the connection on your TV")
    }

    func client(_ client: TVClient, didEncounterError error: TVError) async {
        print("Error: \(error)")
    }
}

client.delegate = MyTVDelegate()
```

---

### 8. Disconnect Properly

```swift
await client.disconnect()
print("Disconnected from TV")
```

## Common Patterns

### Retry on Failure

```swift
func connectWithRetry(to host: String, maxAttempts: Int = 3) async throws {
    for attempt in 1...maxAttempts {
        do {
            try await client.connect(to: host)
            return
        } catch {
            if attempt == maxAttempts { throw error }
            print("Attempt \(attempt) failed, retrying...")
            try await Task.sleep(for: .seconds(2))
        }
    }
}
```

### Execute Multiple Commands

```swift
func navigateToNetflix() async throws {
    try await client.remote.home()
    try await Task.sleep(for: .seconds(1))

    try await client.remote.sendKeys([
        .down,
        .right,
        .right,
        .enter
    ], delay: .milliseconds(300))
}
```

### Upload and Display Custom Art

```swift
func displayCustomArt(imageURL: URL) async throws {
    // Check support
    guard try await client.art.isSupported() else {
        throw TVError.artModeNotSupported
    }

    // Load image
    let imageData = try Data(contentsOf: imageURL)

    // Upload
    let artID = try await client.art.upload(
        imageData,
        type: .jpeg,
        matte: .classicWoodLight
    )

    // Display
    try await client.art.select(artID, show: true)

    print("Custom art displayed successfully!")
}
```

## Error Handling

### Common Errors

```swift
do {
    try await client.connect(to: "192.168.1.100")
} catch TVError.authenticationRequired {
    // User needs to approve on TV
    print("Please approve connection on your TV")
} catch TVError.connectionFailed(let reason) {
    // Network or connection issue
    print("Connection failed: \(reason)")
} catch TVError.timeout {
    // Operation took too long
    print("Connection timeout - check network")
} catch TVError.networkUnreachable {
    // TV not accessible
    print("TV not reachable - check IP address")
} catch TVError.deviceNotFound {
    // TV not found at address
    print("No TV found at this address")
} catch {
    // Unexpected error
    print("Unexpected error: \(error)")
}
```

### Art Mode Errors

```swift
do {
    try await client.art.upload(imageData, type: .jpeg)
} catch TVError.artModeNotSupported {
    print("This TV doesn't support Art Mode")
} catch TVError.uploadFailed(let reason) {
    print("Upload failed: \(reason)")
} catch TVError.invalidImageFormat {
    print("Invalid image format (use JPEG or PNG)")
} catch {
    print("Error: \(error)")
}
```

## Best Practices

### 1. Store Tokens for Seamless Reconnection

```swift
// Use KeychainTokenStorage for automatic token persistence
let storage = KeychainTokenStorage()
try await client.connect(to: host, tokenStorage: storage)
// Token is saved automatically on first connection
// Subsequent connections use stored token (no approval needed)
```

### 2. Handle Authentication Flow

```swift
func connectAndWaitForAuth(to host: String) async throws {
    do {
        try await client.connect(to: host)
    } catch TVError.authenticationRequired {
        // Show UI prompt to user
        await showAuthPrompt("Approve connection on your TV")

        // Wait for connection to complete
        // (library handles auth internally)
    }
}
```

### 3. Command Timing

```swift
// Bad: Commands may fail if sent too quickly
try await client.remote.sendKey(.down)
try await client.remote.sendKey(.enter) // Might fail

// Good: Add delay between commands
try await client.remote.sendKey(.down)
try await Task.sleep(for: .milliseconds(200))
try await client.remote.sendKey(.enter)

// Better: Use sendKeys with automatic delay
try await client.remote.sendKeys([.down, .enter], delay: .milliseconds(200))
```

### 4. Check Connection State

```swift
guard await client.state == .connected else {
    print("Not connected")
    return
}

try await client.remote.volumeUp()
```

### 5. Graceful Disconnection

```swift
// Always disconnect when done
defer {
    Task {
        await client.disconnect()
    }
}

// Use connection
try await client.remote.power()
```

## SwiftUI Integration

### Simple Remote Control View

```swift
struct RemoteControlView: View {
    @State private var client = TVClient()
    @State private var isConnected = false
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            if isConnected {
                VStack {
                    Button("▲") {
                        Task { try? await client.remote.navigate(.up) }
                    }

                    HStack {
                        Button("◀") {
                            Task { try? await client.remote.navigate(.left) }
                        }
                        Button("OK") {
                            Task { try? await client.remote.enter() }
                        }
                        Button("▶") {
                            Task { try? await client.remote.navigate(.right) }
                        }
                    }

                    Button("▼") {
                        Task { try? await client.remote.navigate(.down) }
                    }
                }
                .padding()
            } else {
                Button("Connect") {
                    Task {
                        do {
                            try await client.connect(to: "192.168.1.100")
                            isConnected = true
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
        }
    }
}
```

## Testing

### Mock Client for Tests

```swift
import SwiftSamsungFrame

let mockClient = MockTVClient()
mockClient.mockDeviceInfo = TVDevice(
    id: "test-123",
    name: "Test TV",
    host: "127.0.0.1",
    modelName: "TestModel",
    features: [.artMode]
)

// Use in tests
let info = try await mockClient.deviceInfo()
XCTAssertEqual(info.name, "Test TV")
```

## Performance Tips

1. **Reuse Client Instance**: Create once, use throughout app lifecycle
2. **Connection Pooling**: Maintain persistent connection instead of reconnecting
3. **Batch Commands**: Use `sendKeys()` for multiple commands
4. **Lazy Art Loading**: Load thumbnails on demand, not all at once
5. **Discovery Timeout**: Use shorter timeouts (5s) if you know TV is nearby

## Platform-Specific Notes

### macOS
- Full feature support
- Requires network entitlements in sandbox

### iOS/tvOS
- Full feature support
- Art upload works well on modern devices

### watchOS
- Basic remote control: ✅
- App management: ✅
- Art upload: ❌ (memory constraints)

## Troubleshooting

### Connection Issues

**Problem**: `TVError.networkUnreachable`

**Solutions**:
- Verify TV is on same network
- Check IP address is correct
- Ensure port 8001 is not blocked
- TV may be in standby (wake it first)

**Problem**: `TVError.authenticationRequired` every time

**Solutions**:
- Use `KeychainTokenStorage` for token persistence
- Check TV settings allow remote control
- Token may have been revoked on TV

### Command Failures

**Problem**: Commands timeout or fail

**Solutions**:
- Add delay between commands (200-500ms)
- Check connection state before sending
- Verify TV supports the specific command

## Next Steps

- Read the full [API Reference](contracts/api-reference.md)
- Explore [WebSocket Protocol](contracts/websocket-protocol.md) details
- Check [REST API Specification](contracts/rest-protocol.md) for HTTP endpoints
- Review [Data Model](data-model.md) for all types

## Support

- GitHub Issues: [Report bugs](https://github.com/yourusername/SwiftSamsungFrame/issues)
- Documentation: [Full docs](https://github.com/yourusername/SwiftSamsungFrame/wiki)
- Examples: [Sample projects](https://github.com/yourusername/SwiftSamsungFrame/tree/main/Examples)
