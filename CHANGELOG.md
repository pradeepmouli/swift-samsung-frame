# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-11-11

### Added

#### Core Infrastructure
- Swift 6.2 support with strict concurrency enabled
- Cross-platform support for macOS 15+, iOS 18+, tvOS 18+, watchOS 11+
- Actor-based thread-safe architecture throughout the library
- Keychain-based secure token storage for authentication persistence
- Comprehensive error handling with TVError enum (12 error cases)
- OSLog integration for all subsystems (connection, commands, apps, art, discovery, networking)

#### User Story 4: Connection Management (P1 - MVP)
- TVClient class with WebSocket-based connection to Samsung TVs
- TLS certificate handling for self-signed certificates
- Authentication flow with token exchange and pairing prompts
- Connection state management with async access
- TVClientDelegate callback system for state change notifications
- Graceful WebSocket closure on disconnect
- Comprehensive error handling for timeouts, auth failures, and network issues
- Token persistence using Keychain on Apple platforms

#### User Story 1: Basic TV Control (P1 - MVP)
- RemoteControl implementation with full key support (KeyCode enum)
- Power control (on/off)
- Volume control (up, down, mute) with configurable steps
- Navigation commands (up, down, left, right)
- Convenience methods (enter, back, home)
- Sequential command support with configurable delays
- Command timeout handling (5 second timeout)
- Command retry logic (retry once after 500ms)
- Device information retrieval via REST API

#### User Story 5: Device Discovery (P2)
- DiscoveryService with mDNS/Bonjour support (Apple platforms)
- SSDP discovery protocol implementation
- AsyncStream-based concurrent discovery results
- Manual IP address validation with find(at:) method
- Automatic service type filtering for Samsung TVs
- Discovery strategy: mDNS first (3s), fallback to SSDP (7s)
- Cancel support for stopping discovery
- Platform-specific implementation using Network framework

#### User Story 2: Application Management (P2)
- App listing via WebSocket "ed.installedApp.get" message
- Launch apps with WebSocket "ed.apps.launch" command
- Close running applications
- App status checking
- App icon retrieval via REST API
- JSON parsing and mapping to TVApp models
- Error handling for app not found and launch failures

#### User Story 3: Art Mode Control for Frame TVs (P3)
- Art Mode support detection for Frame TVs
- List available art pieces via WebSocket
- Select and display art content
- Custom image upload via D2D socket protocol (Apple platforms)
- Art deletion (single and bulk operations)
- Thumbnail retrieval via REST API
- Art Mode toggle (enable/disable)
- Photo filter support (list and apply filters)
- Platform checks to disable upload on watchOS (memory constraints)
- Image validation (format and size limits)
- D2D socket implementation using Network framework

#### Networking Infrastructure
- WebSocketClient actor with URLSessionWebSocketTask
- WebSocket message encoding/decoding for JSON commands
- RESTClient using URLSession for HTTP requests
- D2DSocketClient for direct TCP connections (Art Mode transfers)
- MDNSBrowser using Network framework NWBrowser
- SSDPBrowser with UDP multicast support
- Multipart form data encoding for art uploads

#### Models & Data Structures
- TVDevice (Sendable, Identifiable, Hashable, Codable)
- ConnectionSession (Actor-isolated for thread safety)
- AuthenticationToken (Keychain-safe Codable implementation)
- RemoteCommand struct
- TVApp (Sendable, Identifiable, Hashable, Codable)
- ArtPiece (Sendable, Identifiable, Hashable, Codable)
- DiscoveryResult struct
- Comprehensive enumerations: ConnectionState, TVFeature, APIVersion, AppStatus, ArtCategory, ImageType, MatteStyle, PhotoFilter, CommandType, DiscoveryMethod, TokenScope, KeyCode
- NavigationDirection enum with key code mapping

#### Protocols
- TVClientProtocol
- RemoteControlProtocol
- AppManagementProtocol
- ArtControllerProtocol
- DiscoveryServiceProtocol
- TokenStorageProtocol
- TVClientDelegate

#### Extensions
- Duration helpers (milliseconds(), seconds())
- OSLog categories for all subsystems

#### Testing
- Basic unit tests for core models
- Sendable conformance verification
- WebSocket message encoding tests
- Authentication token validation tests
- Navigation direction mapping tests

### Platform-Specific Features

#### Apple Platforms (macOS, iOS, tvOS)
- Full feature support including discovery, D2D transfers, and Keychain storage
- Network framework integration for mDNS and SSDP discovery
- D2D socket implementation for art uploads

#### watchOS
- Basic remote control commands
- Connection management
- Keychain token storage
- Art upload disabled (memory constraints)

#### Linux (Experimental)
- Basic data models and protocols
- Core TVClient functionality
- No Keychain storage (requires custom TokenStorageProtocol)
- No discovery or D2D transfers

### Documentation
- Comprehensive README.md with examples
- SwiftUI integration examples
- macOS command line tool example
- tvOS remote control app example
- Platform-specific usage documentation
- Architecture overview
- API usage examples for all major features

### Development & Tooling
- Swift Package Manager configuration
- SwiftLint configuration for Swift 6 concurrency rules
- .gitignore for SPM projects
- Organized directory structure (Models, Protocols, Client, Networking, Commands, Extensions)

## [0.1.0] - Initial Development

### Added
- Initial project scaffolding
- Basic project structure
- Package.swift configuration

---

## Version History

- **0.2.0** - Full feature release with all user stories (US1-US5) implemented
- **0.1.0** - Initial development phase

## Release Notes

### Version 0.2.0 Highlights

This release represents a production-ready Samsung TV control library with comprehensive feature coverage:

**MVP Features (P1):**
- Stable connection management with authentication
- Complete remote control functionality
- Device information retrieval

**Extended Features (P2):**
- Network device discovery (mDNS/SSDP)
- Application management (list, launch, close)

**Advanced Features (P3):**
- Art Mode control for Samsung Frame TVs
- Custom art upload and management
- Photo filter application

**Quality & Production Readiness:**
- Swift 6 strict concurrency compliance
- Actor-based thread safety
- Comprehensive error handling
- Cross-platform support
- Secure token storage
- Extensive logging and diagnostics

### Known Limitations

1. **Connection Features:**
   - Health check with ping/pong not implemented (deferred)
   - Auto-reconnection with exponential backoff not implemented (deferred)

2. **Platform Support:**
   - Linux support is experimental and limited
   - watchOS has limited features (no art upload)
   - Discovery requires Apple platforms with Network framework

3. **Documentation:**
   - DocC documentation not yet generated
   - Some APIs have partial documentation

### Migration Guide

This is the first public release. No migration needed.

### Upgrading

To upgrade to 0.2.0, update your Package.swift:

```swift
.package(url: "https://github.com/yourusername/swift-samsung-frame.git", from: "0.2.0")
```

### Credits

Developed with reference to:
- [Samsung TV WebSocket API Documentation](https://github.com/xchwarze/samsung-tv-ws-api)
- [Samsung TV Art Updates Branch](https://github.com/xchwarze/samsung-tv-ws-api/tree/art-updates)
- [Samsung Smart TV Remote Control Protocol](https://github.com/Ape/samsungctl)
