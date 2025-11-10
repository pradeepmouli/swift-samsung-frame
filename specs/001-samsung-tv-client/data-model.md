# Data Model: Samsung TV Client Library

**Date**: 2025-11-09
**Feature**: 001-samsung-tv-client

## Overview

This document defines the core data models for the Samsung TV Client library. All models conform to Swift 6 concurrency requirements (`Sendable`) and follow protocol-oriented design principles.

## Core Entities

### TVDevice

Represents a Samsung TV discovered or connected to the network.

**Properties**:
- `id: String` - Unique identifier (derived from MAC address or UUID)
- `host: String` - IP address or hostname
- `port: Int` - WebSocket port (default: 8001)
- `name: String` - Friendly device name (e.g., "Living Room TV")
- `modelName: String?` - TV model identifier (e.g., "UN55LS03RAFXZA")
- `firmwareVersion: String?` - Current firmware version
- `macAddress: String?` - MAC address for Wake-on-LAN
- `supportedFeatures: Set<TVFeature>` - Capabilities (art mode, voice control, etc.)
- `apiVersion: APIVersion` - Supported API version (v1, v2)

**Relationships**:
- Has one `ConnectionState` (current connection status)
- Has optional `AuthenticationToken`
- May support `ArtMode` (Frame TVs only)

**Validation Rules**:
- `host` must be valid IPv4 address or resolvable hostname
- `port` must be in range 1-65535
- `name` must not be empty

**Protocol Conformance**:
- `Sendable` - Thread-safe for concurrent access
- `Identifiable` - Unique ID for SwiftUI lists
- `Hashable` - Dictionary keys and Set membership
- `Codable` - JSON serialization for caching

---

### TVApp

Represents an installed application on the TV.

**Properties**:
- `id: String` - Unique app identifier (e.g., "3201606009684" for Spotify)
- `name: String` - Display name (e.g., "Spotify")
- `version: String?` - App version
- `iconURL: URL?` - Icon image URL
- `isRunning: Bool` - Current execution state
- `lastLaunched: Date?` - Last launch timestamp

**Relationships**:
- Belongs to `TVDevice`
- Has one `AppStatus` (running, stopped, etc.)

**Validation Rules**:
- `id` must not be empty
- `name` must not be empty
- `iconURL` must be valid URL if present

**State Transitions**:
```
Stopped → Launching → Running
Running → Stopping → Stopped
```

**Protocol Conformance**:
- `Sendable`
- `Identifiable`
- `Hashable`
- `Codable`

---

### ArtPiece

Represents artwork available on Frame TVs.

**Properties**:
- `id: String` - Unique art identifier (e.g., "SAM-F0206", "MY-F0020" for uploads)
- `title: String` - Art piece title
- `category: ArtCategory` - Type (preloaded, user-uploaded, store-purchased)
- `thumbnailURL: URL?` - Thumbnail image URL
- `imageType: ImageType` - Format (JPEG, PNG)
- `matteStyle: MatteStyle?` - Frame matte configuration
- `filter: PhotoFilter?` - Applied photo filter
- `uploadDate: Date?` - When uploaded (user content only)
- `fileSize: Int?` - Image size in bytes

**Relationships**:
- Belongs to `TVDevice` (Frame TV)
- Has optional `MatteStyle`
- Has optional `PhotoFilter`

**Validation Rules**:
- `id` must not be empty
- `title` must not be empty
- `fileSize` must be >0 if present
- User-uploaded IDs must match pattern "MY-*"

**Protocol Conformance**:
- `Sendable`
- `Identifiable`
- `Hashable`
- `Codable`

---

### RemoteCommand

Represents a remote control action to send to the TV.

**Properties**:
- `keyCode: KeyCode` - The key to press (e.g., `power`, `volumeUp`, `home`)
- `type: CommandType` - Press, hold, or release
- `timestamp: Date` - When command was created
- `repeatCount: Int` - Number of times to repeat (default: 1)

**Validation Rules**:
- `repeatCount` must be >= 1
- `repeatCount` should warn if > 10 (rapid repeat risk)

**Common Key Codes**:
- Power: `KEY_POWER`, `KEY_POWEROFF`
- Volume: `KEY_VOLUP`, `KEY_VOLDOWN`, `KEY_MUTE`
- Navigation: `KEY_UP`, `KEY_DOWN`, `KEY_LEFT`, `KEY_RIGHT`, `KEY_ENTER`
- Playback: `KEY_PLAY`, `KEY_PAUSE`, `KEY_STOP`, `KEY_FF`, `KEY_REW`
- Channel: `KEY_CHUP`, `KEY_CHDOWN`, `KEY_PRECH`
- Menu: `KEY_MENU`, `KEY_HOME`, `KEY_BACK`, `KEY_EXIT`

**Protocol Conformance**:
- `Sendable`
- `Codable`

---

### ConnectionSession

Represents an active connection to a TV.

**Properties**:
- `id: UUID` - Unique session identifier
- `device: TVDevice` - Connected device
- `state: ConnectionState` - Current state (disconnected, connecting, connected, error)
- `authToken: String?` - Authentication token for reconnection
- `websocket: URLSessionWebSocketTask?` - Active WebSocket connection
- `connectedAt: Date?` - Connection establishment time
- `lastActivity: Date` - Last communication timestamp
- `healthCheckInterval: TimeInterval` - Ping interval (default: 30s)

**State Transitions**:
```
Disconnected → Connecting → Authenticating → Connected
Connected → Disconnecting → Disconnected
Any → Error
```

**Validation Rules**:
- `authToken` must be valid JWT-like string if present
- `healthCheckInterval` must be >= 10 seconds
- `websocket` must be non-nil when state is `connected`

**Protocol Conformance**:
- `Sendable` (managed by Actor)
- `Identifiable`

---

### DiscoveryResult

Represents a discovered TV on the network.

**Properties**:
- `device: TVDevice` - Discovered device information
- `discoveryMethod: DiscoveryMethod` - How it was found (SSDP, mDNS)
- `discoveredAt: Date` - When discovered
- `signalStrength: Int?` - Network signal quality (0-100)
- `isReachable: Bool` - Whether device responds to ping

**Relationships**:
- Contains one `TVDevice`

**Validation Rules**:
- `signalStrength` must be 0-100 if present

**Protocol Conformance**:
- `Sendable`
- `Identifiable` (via device.id)

---

### AuthenticationToken

Represents a secure token for maintaining authenticated sessions.

**Properties**:
- `value: String` - Token string (opaque)
- `deviceID: String` - Associated device ID
- `issuedAt: Date` - When token was created
- `expiresAt: Date?` - Expiration time (if known)
- `scope: Set<TokenScope>` - Permitted operations

**Validation Rules**:
- `value` must not be empty
- If `expiresAt` present, must be > `issuedAt`
- `value` should be treated as sensitive (not logged)

**Security**:
- Stored in Keychain
- Never serialized to disk unencrypted
- Cleared on logout or expiration

**Protocol Conformance**:
- `Sendable`
- Custom `Codable` (encrypts value)
- `Equatable` (for comparison)

---

## Enumerations

### ConnectionState

```swift
enum ConnectionState: String, Sendable, Codable {
    case disconnected
    case connecting
    case authenticating
    case connected
    case disconnecting
    case error
}
```

### TVFeature

```swift
enum TVFeature: String, Sendable, Codable {
    case artMode
    case voiceControl
    case ambientMode
    case gameMode
    case multiView
    case screenMirroring
}
```

### APIVersion

```swift
enum APIVersion: String, Sendable, Codable {
    case v1 // Encrypted API (J/K series)
    case v2 // Modern WebSocket API (2016+)
}
```

### AppStatus

```swift
enum AppStatus: String, Sendable, Codable {
    case stopped
    case launching
    case running
    case paused
    case stopping
}
```

### ArtCategory

```swift
enum ArtCategory: String, Sendable, Codable {
    case preloaded   // Samsung-provided art
    case uploaded    // User-uploaded images
    case purchased   // Art Store purchases
}
```

### ImageType

```swift
enum ImageType: String, Sendable, Codable {
    case jpeg
    case png
}
```

### MatteStyle

```swift
enum MatteStyle: String, Sendable, Codable {
    case none
    case modernBeige = "modern_beige"
    case modernApricot = "modern_apricot"
    case modernIvory = "modern_ivory"
    case modernBrown = "modern_brown"
    case modernWalnut = "modern_walnut"
    case vintageWhite = "vintage_white"
    case vintageBeige = "vintage_beige"
    case vintageWalnut = "vintage_walnut"
}
```

### PhotoFilter

```swift
enum PhotoFilter: String, Sendable, Codable {
    case none
    case ink
    case watercolor
    case pencil
    case pastel
    case comic
    case oilPainting = "oil_painting"
}
```

### CommandType

```swift
enum CommandType: String, Sendable, Codable {
    case press   // Single key press
    case hold    // Press and hold
    case release // Release held key
}
```

### DiscoveryMethod

```swift
enum DiscoveryMethod: String, Sendable, Codable {
    case ssdp      // SSDP/UPnP discovery
    case mdns      // Bonjour/mDNS discovery
    case manual    // Manually added by IP
}
```

### TokenScope

```swift
enum TokenScope: String, Sendable, Codable {
    case remoteControl
    case appManagement
    case artMode
    case deviceInfo
}
```

### KeyCode

```swift
enum KeyCode: String, Sendable, Codable {
    // Power
    case power = "KEY_POWER"
    case powerOff = "KEY_POWEROFF"
    
    // Volume
    case volumeUp = "KEY_VOLUP"
    case volumeDown = "KEY_VOLDOWN"
    case mute = "KEY_MUTE"
    
    // Navigation
    case up = "KEY_UP"
    case down = "KEY_DOWN"
    case left = "KEY_LEFT"
    case right = "KEY_RIGHT"
    case enter = "KEY_ENTER"
    case back = "KEY_RETURN"
    
    // Playback
    case play = "KEY_PLAY"
    case pause = "KEY_PAUSE"
    case stop = "KEY_STOP"
    case rewind = "KEY_REWIND"
    case fastForward = "KEY_FF"
    
    // Channel
    case channelUp = "KEY_CHUP"
    case channelDown = "KEY_CHDOWN"
    case previousChannel = "KEY_PRECH"
    
    // Menu
    case menu = "KEY_MENU"
    case home = "KEY_HOME"
    case exit = "KEY_EXIT"
    case source = "KEY_SOURCE"
    case tools = "KEY_TOOLS"
    
    // Numbers
    case num0 = "KEY_0"
    case num1 = "KEY_1"
    case num2 = "KEY_2"
    case num3 = "KEY_3"
    case num4 = "KEY_4"
    case num5 = "KEY_5"
    case num6 = "KEY_6"
    case num7 = "KEY_7"
    case num8 = "KEY_8"
    case num9 = "KEY_9"
}
```

## Error Types

```swift
enum TVError: Error, Sendable {
    case connectionFailed(reason: String)
    case authenticationRequired
    case authenticationFailed
    case timeout(operation: String)
    case networkUnreachable
    case invalidResponse(details: String)
    case commandFailed(code: Int, message: String)
    case artModeNotSupported
    case invalidImageFormat(expected: ImageType)
    case uploadFailed(reason: String)
    case deviceNotFound(id: String)
    case tokenExpired
    case unsupportedAPIVersion(APIVersion)
}
```

## JSON Message Formats

### WebSocket Command Message

```json
{
  "method": "ms.remote.control",
  "params": {
    "Cmd": "Click",
    "DataOfCmd": "KEY_POWER",
    "Option": "false",
    "TypeOfRemote": "SendRemoteKey"
  }
}
```

### Authentication Response

```json
{
  "event": "ms.channel.connect",
  "data": {
    "token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
    "name": "SwiftSamsungFrame"
  }
}
```

### App List Response

```json
{
  "applications": [
    {
      "appId": "111299001912",
      "name": "YouTube",
      "type": 2,
      "icon": "/path/to/icon.png",
      "running": false
    }
  ]
}
```

### Art List Response

```json
{
  "content_list": [
    {
      "content_id": "SAM-F0206",
      "title": "Coastal Sunset",
      "category": "PRELOADED",
      "image_url": "/api/v2/art/ms/content/SAM-F0206/thumbnail"
    }
  ]
}
```

## Relationships Diagram

```
TVDevice
├── ConnectionSession (1:1 when connected)
├── AuthenticationToken (0:1)
├── TVApp (1:many)
└── ArtPiece (1:many, Frame TVs only)

ConnectionSession
├── TVDevice (1:1)
├── AuthenticationToken (0:1)
└── ConnectionState (embedded)

DiscoveryResult
└── TVDevice (embedded)

RemoteCommand
└── KeyCode (embedded)

ArtPiece
├── MatteStyle (0:1)
└── PhotoFilter (0:1)
```

## Implementation Notes

### Thread Safety

- All models conform to `Sendable`
- Mutable state (ConnectionSession) managed by Actor
- Immutable models use `let` properties
- Collections use `Set` or `Array` (both Sendable)

### Persistence

- `TVDevice`: Cache in UserDefaults for quick reconnection
- `AuthenticationToken`: Store in Keychain (secure)
- `TVApp`: Transient, fetch on demand
- `ArtPiece`: Cache thumbnails, fetch metadata on demand

### Testing

- All models have default initializers for testing
- Mock models use same protocols as production
- Codable conformance tested with round-trip JSON encoding
