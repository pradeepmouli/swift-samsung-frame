// SwiftSamsungFrame
// A Swift library for controlling Samsung Smart TVs and Frame TVs

/// SwiftSamsungFrame provides a type-safe, async/await API for controlling Samsung Smart TVs.
///
/// ## Quick Start
///
/// ```swift
/// import SwiftSamsungFrame
///
/// // Create a TV device
/// let device = TVDevice(
///     id: "my-tv",
///     ipAddress: "192.168.1.100",
///     name: "Living Room TV"
/// )
///
/// // Create and connect client
/// let client = TVClient()
/// try await client.connect(to: device)
///
/// // Send commands
/// try await client.remote.power()
/// try await client.remote.volumeUp()
///
/// // Disconnect
/// await client.disconnect()
/// ```
///
/// ## Features
///
/// - **Connection Management**: Secure WebSocket connections with automatic reconnection
/// - **Authentication**: Token-based auth with Keychain storage
/// - **Remote Control**: Send TV remote commands programmatically
/// - **Error Handling**: Comprehensive error types for all scenarios
/// - **Concurrency**: Built with Swift 6 strict concurrency
///
/// ## Main Components
///
/// - ``TVClient``: Main entry point for TV control
/// - ``TVDevice``: Represents a Samsung TV
/// - ``RemoteControlProtocol``: Remote control operations
/// - ``TVClientDelegate``: Connection event notifications
/// - ``TVError``: Error types
/// - ``ConnectionState``: Connection lifecycle states
///
@_exported import struct Foundation.URL
@_exported import struct Foundation.Data
