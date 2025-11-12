// ExampleUsage - Demonstrates basic usage patterns for SwiftSamsungFrame
// This file provides practical examples for connecting to and controlling Samsung TVs

import Foundation
import SwiftSamsungFrame

// MARK: - Example 1: Basic Connection and Remote Control

/// Demonstrates the simplest usage pattern: connect and send commands
func exampleBasicConnection() async throws {
    // Create a TV client instance
    let client = TVClient()

    // Connect to TV at a known IP address
    print("Connecting to TV...")
    _ = try await client.connect(to: "192.168.1.100")
    print("Connected successfully!")

    // Get device information
    let device = try await client.deviceInfo()
    print("Connected to: \(device.name) (Model: \(device.modelName ?? "Unknown"))")

    // Send basic remote control commands
    print("Sending power command...")
    try await client.remote.power()

    // Wait a moment for TV to respond
    try await Task.sleep(for: .seconds(2))

    print("Adjusting volume...")
    try await client.remote.volumeUp(steps: 5)

    // Navigate menus
    print("Navigating menu...")
    try await client.remote.navigate(.down)
    try await client.remote.navigate(.down)
    try await client.remote.enter()

    // Clean disconnect
    print("Disconnecting...")
    await client.disconnect()
    print("Example complete!")
}

// MARK: - Example 2: Connection with Token Persistence

/// Demonstrates using Keychain for token persistence across connections
func examplePersistentConnection() async throws {
    // Use Keychain storage for auth tokens
    let storage = KeychainTokenStorage()
    let client = TVClient()

    print("Connecting with token persistence...")
    _ = try await client.connect(
        to: "192.168.1.100",
        tokenStorage: storage
    )

    // First connection: TV will show pairing prompt, token is saved
    // Subsequent connections: Token is reused automatically

    print("Connected! Token saved for future use.")

    // Send commands
    try await client.remote.home()

    await client.disconnect()
}

// MARK: - Example 3: Error Handling

/// Demonstrates comprehensive error handling
func exampleErrorHandling() async {
    let client = TVClient()

    do {
        _ = try await client.connect(to: "192.168.1.100")

        // Try sending a command
        try await client.remote.power()

    } catch TVError.connectionFailed(let reason) {
        print("Connection failed: \(reason)")
        // Handle connection failure (check network, TV is on, etc.)

    } catch TVError.authenticationFailed {
        print("Authentication failed - check TV pairing prompt")
        // User may need to accept pairing on TV

    } catch TVError.timeout {
        print("Command timed out - TV may be unresponsive")
        // Retry or check TV state

    } catch TVError.networkUnreachable {
        print("Network unreachable - check WiFi connection")
        // Verify network connectivity

    } catch {
        print("Unexpected error: \(error.localizedDescription)")
    }

    await client.disconnect()
}

// MARK: - Example 4: Application Management

/// Demonstrates launching and managing TV apps
func exampleAppManagement() async throws {
    let client = TVClient()

    print("Connecting to TV...")
    _ = try await client.connect(to: "192.168.1.100")

    // List installed apps
    print("Fetching installed apps...")
    let apps = try await client.apps.list()
    print("Found \(apps.count) installed apps:")
    for app in apps.prefix(5) {
        print("  - \(app.name) (ID: \(app.id))")
    }

    // Launch YouTube (example app ID)
    let youtubeAppID = "111299001912"
    print("\nLaunching YouTube...")
    try await client.apps.launch(youtubeAppID)

    // Wait for app to launch
    try await Task.sleep(for: .seconds(3))

    // Check app status
    let status = try await client.apps.status(of: youtubeAppID)
    print("YouTube status: \(status)")

    // Close the app
    print("Closing YouTube...")
    try await client.apps.close(youtubeAppID)

    await client.disconnect()
}

// MARK: - Example 5: Art Mode Control (Frame TVs)

/// Demonstrates Art Mode features for Samsung Frame TVs
func exampleArtMode() async throws {
    let client = TVClient()

    print("Connecting to Frame TV...")
    _ = try await client.connect(to: "192.168.1.100")

    // Check if Art Mode is supported
    let isSupported = try await client.art.isSupported()
    guard isSupported else {
        print("Art Mode not supported on this TV")
        await client.disconnect()
        return
    }

    print("Art Mode is supported!")

    // List available art
    print("Fetching available art...")
    let artPieces = try await client.art.listAvailable()
    print("Found \(artPieces.count) art pieces:")
    for art in artPieces.prefix(5) {
        print("  - \(art.title)")
    }

    // Select an art piece
    if let firstArt = artPieces.first {
        print("\nSelecting art: \(firstArt.title)")
        try await client.art.select(firstArt.id, show: true)
    }

    // Check if Art Mode is active
    let isActive = try await client.art.isArtModeActive()
    print("Art Mode active: \(isActive)")

    // Get available filters
    let filters = try await client.art.availableFilters()
    print("\nAvailable filters: \(filters.map { String(describing: $0) }.joined(separator: ", "))")

    // Apply a filter to current art
    if let firstArt = artPieces.first, !filters.isEmpty {
        print("Applying \(filters[0]) filter...")
        try await client.art.applyFilter(filters[0], to: firstArt.id)
    }

    await client.disconnect()
}

// MARK: - Example 6: Device Discovery

/// Demonstrates finding TVs on the network
func exampleDeviceDiscovery() async throws {
    let discovery = DiscoveryService()

    // Method 1: Manual lookup of known TV
    print("Looking up TV at 192.168.1.100...")
    do {
        let result = try await discovery.find(at: "192.168.1.100")
        print("Found: \(result.device.name)")
        print("  Model: \(result.device.modelName ?? "Unknown")")
        print("  Host: \(result.device.host)")
    } catch {
        print("TV not found at address: \(error.localizedDescription)")
    }

    // Method 2: Automatic network discovery (Apple platforms only)
    #if canImport(Network)
    print("\nScanning network for Samsung TVs...")
    var foundDevices: [TVDevice] = []

    for await result in discovery.discover(timeout: .seconds(5)) {
        print("Discovered: \(result.device.name) at \(result.device.host)")
        print("  Method: \(result.discoveryMethod)")
        foundDevices.append(result.device)
    }

    print("\nDiscovery complete. Found \(foundDevices.count) device(s).")
    #else
    print("\nAutomatic discovery not available on this platform.")
    print("Use find(at:) method with known IP addresses.")
    #endif
}

// MARK: - Example 7: Sequential Commands with Delay

/// Demonstrates sending multiple commands in sequence
func exampleSequentialCommands() async throws {
    let client = TVClient()

    print("Connecting to TV...")
    _ = try await client.connect(to: "192.168.1.100")

    // Navigate to an app using sequential key presses
    print("Navigating to Netflix...")
    let navigationSequence: [KeyCode] = [
        .home,      // Go to home screen
        .down,      // Navigate down
        .down,      // Navigate down
        .right,     // Navigate right
        .enter      // Select
    ]

    // Send keys with 300ms delay between each
    try await client.remote.sendKeys(
        navigationSequence,
        delay: .milliseconds(300)
    )

    print("Navigation sequence complete!")

    await client.disconnect()
}

// MARK: - Example 8: Using TVClientDelegate

/// Demonstrates monitoring connection state changes
actor ConnectionMonitor: TVClientDelegate {
    var connectionEvents: [String] = []

    func client(_ client: any TVClientProtocol, didChangeState state: ConnectionState) async {
        let event = "State changed to: \(state)"
        connectionEvents.append(event)
        print("📡 \(event)")
    }

    func clientRequiresAuthentication(_ client: any TVClientProtocol) async {
        let event = "Authentication required"
        connectionEvents.append(event)
        print("🔑 \(event)")
    }

    func client(_ client: any TVClientProtocol, didEncounterError error: TVError) async {
        let event = "Error occurred: \(error.localizedDescription)"
        connectionEvents.append(event)
        print("⚠️ \(event)")
    }
}

func exampleWithDelegate() async throws {
    let monitor = ConnectionMonitor()
    let client = TVClient()

    // Note: setDelegate is not yet implemented in TVClient
    // This example shows the intended usage pattern
    // await client.setDelegate(monitor)

    print("Connecting with state monitoring...")
    _ = try await client.connect(to: "192.168.1.100")

    // Delegate receives state change notifications
    try await Task.sleep(for: .seconds(1))

    // Send a command
    try await client.remote.power()

    await client.disconnect()

    // Review captured events
    let events = await monitor.connectionEvents
    print("\nCaptured \(events.count) connection events:")
    for event in events {
        print("  - \(event)")
    }
}

// MARK: - Example 9: Platform-Specific Features

/// Demonstrates handling platform-specific capabilities
func examplePlatformSpecific() async throws {
    let client = TVClient()
    _ = try await client.connect(to: "192.168.1.100")

    #if canImport(Network)
    // D2D upload available on iOS, macOS, tvOS
    print("Platform supports D2D art upload")

    #if !os(watchOS)
    // Upload custom art (not on watchOS due to memory constraints)
    if try await client.art.isSupported() {
        print("Uploading custom art...")
        // In real usage, load image from file
        let imageData = Data() // Placeholder
        if !imageData.isEmpty {
            let artID = try await client.art.upload(
                imageData,
                type: .jpeg,
                matte: .modernBeige
            )
            print("Uploaded art with ID: \(artID)")
        }
    }
    #else
    print("Art upload disabled on watchOS")
    #endif

    #else
    print("D2D features not available on this platform")
    #endif

    await client.disconnect()
}

// MARK: - Example 10: MockTVClient for Testing

/// Demonstrates using MockTVClient in unit tests
func exampleMockUsage() async throws {
    // Create mock with configured responses
    let mockRemote = MockRemoteControl()
    let mock = MockTVClient(remote: mockRemote)

    // Configure mock behavior using actor-safe methods
    await mock.configure(state: .connected)
    await mock.configure(device: TVDevice(
        id: "test-tv",
        host: "192.168.1.100",
        port: 8001,
        name: "Test TV",
        modelName: "Test Model",
        macAddress: "00:00:00:00:00:00"
    ))

    // Use mock in tests
    let state = await mock.state
    print("Mock state: \(state)")

    let device = try await mock.deviceInfo()
    print("Mock device: \(device.name)")

    // Send command to mock
    try await mock.remote.power()

    // Verify command was called
    let powerCallCount = await mockRemote.powerCallCount
    print("Power was called \(powerCallCount) time(s)")

    // Reset mock for next test
    await mock.reset()
}

// MARK: - Running Examples

// Uncomment the example you want to run:

// Example usage in a command-line tool:
/*
@main
struct ExampleRunner {
    static func main() async throws {
        print("SwiftSamsungFrame Examples\n")

        // Choose which example to run:
        try await exampleBasicConnection()
        // try await examplePersistentConnection()
        // try await exampleErrorHandling()
        // try await exampleAppManagement()
        // try await exampleArtMode()
        // try await exampleDeviceDiscovery()
        // try await exampleSequentialCommands()
        // try await exampleWithDelegate()
        // try await examplePlatformSpecific()
        // try await exampleMockUsage()
    }
}
*/
