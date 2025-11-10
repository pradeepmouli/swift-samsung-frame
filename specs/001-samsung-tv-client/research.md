# Research: Samsung TV Client Library

**Date**: 2025-11-09
**Feature**: 001-samsung-tv-client

## Overview

This document consolidates research findings for implementing a Swift client library for Samsung TVs, based on analysis of the reference Python implementation (samsung-tv-ws-api) and Swift ecosystem best practices.

## Technology Decisions

### 1. WebSocket Client Library

**Decision**: Use native `URLSessionWebSocketTask` (Foundation)

**Rationale**:
- **Zero dependencies**: Available in Foundation (iOS 13+, macOS 10.15+), well within our target platforms (iOS 18+, macOS 15+)
- **Swift concurrency native**: Full async/await support built-in, aligns with Strict Concurrency principle
- **Apple maintained**: Long-term support guaranteed, no third-party maintenance risk
- **Sendable compliance**: Designed for Swift 6 concurrency model
- **Platform consistency**: Same API across all Apple platforms

**Alternatives Considered**:
- **Starscream**: Popular third-party library but adds dependency, requires additional Sendable conformance work
- **swift-nio**: Powerful but over-engineered for this use case, larger dependency footprint
- **Verdict**: Native solution preferred per constitution's simplicity and zero-dependency approach

### 2. HTTP/REST Client

**Decision**: Use native `URLSession` with `async/await`

**Rationale**:
- Consistent with WebSocket choice (same Foundation framework)
- Full async/await support for REST endpoints
- Built-in support for JSON encoding/decoding via `Codable`
- No additional dependencies

**Alternatives Considered**:
- **AsyncHTTPClient**: Swift Server workgroup library, well-designed but adds dependency
- **Alamofire**: Popular but heavyweight, not needed for this use case
- **Verdict**: URLSession sufficient for Samsung TV REST API needs

### 3. Network Discovery (SSDP/mDNS)

**Decision**: Use native `NWBrowser` (Network framework) for **mDNS/Bonjour as primary discovery method**, with SSDP implementation over `NWConnection` as fallback

**Rationale**:
- **Primary: mDNS (Bonjour)**: Samsung Frame TVs advertise via mDNS/Bonjour services (`_samsung-remote._tcp`)
- **Network framework**: Apple's modern networking stack with async support
- **NWBrowser**: Natively supports Bonjour/mDNS service discovery with AsyncSequence integration
- **Fallback: SSDP**: Older Samsung TV models (pre-2018) use SSDP (Simple Service Discovery Protocol), requires custom UDP multicast implementation
- **Cross-platform**: Network framework available on all target platforms (macOS 10.14+, iOS 12+)
- **Concurrency**: Designed for Swift concurrency model with async/await patterns

**Implementation Notes**:
- **mDNS Discovery** (Primary):
  - Service type: `_samsung-remote._tcp.local.`
  - NWBrowser automatically resolves IP addresses and ports
  - Filter results for Frame TV models via TXT records
  - Integrate with AsyncStream for Swift concurrency
  
- **SSDP Discovery** (Fallback):
  - M-SEARCH multicast to 239.255.255.250:1900
  - Parse SSDP responses for Samsung TV identification (URN: `urn:samsung.com:device:RemoteControlReceiver`)
  - Custom UDP multicast implementation using NWConnection
  
- **Discovery Strategy**: Try mDNS first (3s timeout), fall back to SSDP if no Frame TVs found (7s timeout total)

**Alternatives Considered**:
- **CocoaAsyncSocket**: Mature but Objective-C-based, not Swift-first
- **Third-party SSDP libraries**: None mature for Swift 6 concurrency
- **Verdict**: Custom SSDP implementation using Network framework most aligned with constitution

### 4. Image Processing (Art Mode)

**Decision**: Use native platform image APIs (`NSImage`/`UIImage`) with minimal processing

**Rationale**:
- Art upload requires JPEG/PNG encoding, natively supported
- Image resizing/formatting handled by platform APIs
- No complex image manipulation needed
- Cross-platform abstraction minimal (`#if` directives for macOS vs iOS)

**Implementation Notes**:
- Accept Data, URL, or platform-native image types
- Convert to JPEG/PNG data for upload
- Validate image size/format before upload

### 5. Secure Storage (Auth Tokens)

**Decision**: `Keychain` for macOS/iOS/tvOS/watchOS, with fallback to encrypted `UserDefaults`

**Rationale**:
- **Security**: Auth tokens are sensitive, Keychain provides system-level encryption
- **Cross-platform**: Keychain available on all Apple platforms
- **Accessibility**: Can be configured for device-only access
- **Fallback**: UserDefaults for non-critical tokens or user preference

**Implementation Notes**:
- KeychainAccess protocol for testability
- Default implementation uses Security framework
- Mock implementation for unit tests

**Alternatives Considered**:
- **UserDefaults only**: Not secure for auth tokens
- **Third-party keychain wrappers**: Adds dependency, not needed
- **Verdict**: Native Keychain with protocol abstraction for tests

### 6. Logging

**Decision**: Use `OSLog` (unified logging system)

**Rationale**:
- Native Apple logging framework
- Structured logging support
- Performance optimized (privacy-aware, log levels)
- Console.app integration on macOS
- Aligns with Swift coding standards

**Implementation Notes**:
- Create subsystem `com.swiftsamsungframe`
- Categories: `connection`, `commands`, `apps`, `art`, `discovery`
- Default to `.info` level, `.debug` for verbose

**Alternatives Considered**:
- **swift-log**: Server-side Swift logging, adds dependency
- **Print statements**: Not production-ready
- **Verdict**: OSLog for production, print for development convenience

## Protocol Design Patterns

### Core Protocols

Based on protocol-oriented design principle:

```
TVClientProtocol
├── connect() async throws
├── disconnect() async
├── send(command:) async throws
└── var state: ConnectionState { get }

RemoteControlProtocol
├── sendKey(_:) async throws
├── power() async throws
├── volumeUp() async throws
└── navigate(direction:) async throws

AppManagementProtocol
├── listApps() async throws -> [TVApp]
├── launch(appID:) async throws
├── close(appID:) async throws
└── status(appID:) async throws -> AppStatus

ArtControllerProtocol (Frame TVs)
├── isSupported() async throws -> Bool
├── listArt() async throws -> [ArtPiece]
├── select(artID:) async throws
├── upload(image:matte:) async throws -> String
└── toggleArtMode(_:) async throws

DiscoveryServiceProtocol
├── discover(timeout:) async throws -> [TVDevice]
└── cancel()
```

### Actor-based State Management

Connection state managed by Actor:

```
actor ConnectionManager {
    private var state: ConnectionState
    private var websocket: URLSessionWebSocketTask?
    private var authToken: String?
    
    func connect(to host: String) async throws
    func send(message: Message) async throws
    func receive() async throws -> Message
}
```

**Rationale**: Actor eliminates data races in connection state, aligns with Strict Concurrency principle

## API Communication Patterns

### WebSocket Protocol

**Based on Python reference implementation analysis**:

1. **Connection**: `ws://[TV_IP]:8001/api/v2/channels/samsung.remote.control?name=[BASE64_NAME]`
2. **Authentication**: TV displays prompt, responds with auth token in JSON message
3. **Message Format**: JSON with `method` and `params`
4. **Keep-alive**: Ping/pong every 30 seconds
5. **Commands**: Send as JSON: `{"method":"ms.remote.control","params":{"Cmd":"Click","DataOfCmd":"KEY_POWER"}}`

### REST API Endpoints

**Port 8001** (HTTP):
- `GET /api/v2/` - Device info
- `GET /api/v2/applications` - List installed apps
- `POST /api/v2/applications/[APP_ID]` - Launch app
- `DELETE /api/v2/applications/[APP_ID]` - Close app
- `GET /api/v2/applications/[APP_ID]` - App status

**Art Mode API** (Frame TVs):
- `GET /api/v2/art/ms/content` - List art
- `GET /api/v2/art/ms/content/[ART_ID]` - Get art details
- `PUT /api/v2/art/ms/content/[ART_ID]` - Select art
- `POST /api/v2/art/ms/content` - Upload art
- `DELETE /api/v2/art/ms/content/[ART_ID]` - Delete art
- `GET /api/v2/art/ms/artmode` - Get art mode status
- `PUT /api/v2/art/ms/artmode` - Set art mode

## Error Handling Strategy

### Error Types

```
enum TVError: Error, Sendable {
    case connectionFailed(reason: String)
    case authenticationRequired
    case authenticationFailed
    case timeout
    case networkUnreachable
    case invalidResponse
    case commandFailed(code: Int, message: String)
    case artModeNotSupported
    case invalidImageFormat
    case uploadFailed(reason: String)
}
```

### Recovery Strategies

- **Connection failures**: Automatic retry with exponential backoff (1s, 2s, 4s max)
- **Auth token expired**: Clear token, re-authenticate
- **Network unavailable**: Notify via callback, pause operations
- **Invalid commands**: Return error immediately, don't retry

## Testing Strategy

### Unit Tests

- Mock URLSessionWebSocketTask for WebSocket tests
- Mock URLSession for REST API tests
- Protocol-based dependency injection for all network layers
- Test all error paths and edge cases

### Integration Tests

- Mock TV simulator responding to WebSocket/REST
- End-to-end flow tests (connect → auth → command → disconnect)
- Cross-platform tests on macOS and iOS simulators

### Device Tests (Manual)

- Test with actual Samsung Frame TV (2019+ model preferred)
- Verify all remote commands
- Verify art upload/selection
- Verify multi-hour connection stability

## Performance Considerations

### Connection Pooling

- Reuse single WebSocket connection per TV
- REST calls use ephemeral URLSession tasks
- Connection health checks every 30s

### Image Upload Optimization

- Resize images to TV's preferred resolution before upload
- Stream large images rather than load fully into memory
- Progress reporting for uploads >1MB

### Concurrency

- Use TaskGroup for parallel app status checks
- AsyncSequence for streaming discovery results
- Limit concurrent operations to avoid overwhelming TV

## Security Considerations

### Token Storage

- Keychain with `kSecAttrAccessibleWhenUnlocked`
- Device-only access (no iCloud sync)
- Clear tokens on logout/error

### Network Security

- Local network only (no internet exposure)
- Validate SSL certificates if HTTPS used
- No plaintext password storage

### Data Validation

- Validate all JSON responses before parsing
- Sanitize user-provided strings in commands
- Limit image upload sizes to prevent DoS

## Migration Path from Python Reference

### API Naming Conventions

Python → Swift translations:
- `tv.shortcuts().power()` → `remoteControl.power()`
- `tv.app_list()` → `apps.list()`
- `tv.art().available()` → `art.listAvailable()`
- `tv.rest_device_info()` → `client.deviceInfo()`

### Async Patterns

Python uses callbacks/blocking → Swift uses async/await:
- Python: `tv.app_list()` (blocking)
- Swift: `await apps.list()` (async)

## Open Questions Resolved

### Q: Should we support pre-2016 TVs?

**Resolution**: No. Focus on 2016+ (K-series and later) as specified in requirements. Older models use different protocols and would significantly increase complexity.

### Q: CLI tool or library only?

**Resolution**: Library only for initial release. CLI tool can be separate package depending on this library (follows Single Responsibility Principle).

### Q: Support for encrypted API (J/K series)?

**Resolution**: Defer to v2.0. Initial focus on modern TVs with standard WebSocket API. Encrypted API adds significant complexity for limited benefit (J/K series are 2014-2016 models approaching end-of-life).

## Next Steps

Proceed to Phase 1:
1. Create data-model.md with entity definitions
2. Generate contracts/ with API specifications
3. Write quickstart.md with usage examples
4. Update agent context with technology decisions
