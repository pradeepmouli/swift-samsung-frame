import Foundation
@testable import SwiftSamsungFrame

/// Example demonstrating basic usage of the SwiftSamsungFrame library
///
/// This example shows how to:
/// 1. Create a TV device
/// 2. Connect to the TV
/// 3. Send remote control commands
/// 4. Handle errors
/// 5. Disconnect gracefully
func exampleBasicUsage() async {
    print("=== SwiftSamsungFrame Basic Usage Example ===\n")
    
    // Step 1: Create a TV device
    let device = TVDevice(
        id: "living-room-tv",
        ipAddress: "192.168.1.100", // Replace with your TV's IP
        modelName: "QN55Q80A",
        name: "Living Room Samsung TV"
    )
    
    // Step 2: Create a TV client
    let client = TVClient()
    
    do {
        // Step 3: Connect to the TV
        print("Connecting to TV at \(device.ipAddress)...")
        
        // Note: On first connection, a pairing prompt will appear on the TV
        // The user must approve the connection on the TV screen
        try await client.connect(to: device)
        
        print("✅ Connected successfully!\n")
        
        // Step 4: Get device information
        print("Retrieving device info...")
        let info = try await client.deviceInfo()
        print("Device info: \(info)\n")
        
        // Step 5: Send remote control commands
        print("Sending remote control commands...\n")
        
        // Power toggle
        print("- Toggling power...")
        try await client.remote.power()
        try await Task.sleep(for: .seconds(2))
        
        // Volume control
        print("- Increasing volume by 3 steps...")
        try await client.remote.volumeUp(steps: 3)
        try await Task.sleep(for: .seconds(1))
        
        print("- Decreasing volume by 2 steps...")
        try await client.remote.volumeDown(steps: 2)
        try await Task.sleep(for: .seconds(1))
        
        // Navigation
        print("- Navigating: Up → Down → Enter")
        try await client.remote.navigate(.up)
        try await Task.sleep(for: .milliseconds(300))
        
        try await client.remote.navigate(.down)
        try await Task.sleep(for: .milliseconds(300))
        
        try await client.remote.enter()
        try await Task.sleep(for: .seconds(1))
        
        // Send multiple keys with automatic delay
        print("- Sending key sequence: Down, Down, Right, Enter")
        try await client.remote.sendKeys([.down, .down, .right, .enter], delay: 300)
        
        print("\n✅ All commands sent successfully!")
        
    } catch let error as TVError {
        print("❌ TV Error: \(error.localizedDescription)")
    } catch {
        print("❌ Unexpected error: \(error.localizedDescription)")
    }
    
    // Step 6: Disconnect
    print("\nDisconnecting...")
    await client.disconnect()
    print("✅ Disconnected\n")
    
    print("=== Example Complete ===")
}

/// Example demonstrating delegate usage for connection events
final class ExampleDelegate: TVClientDelegate, @unchecked Sendable {
    func tvClient(didChangeState state: ConnectionState) async {
        print("🔄 Connection state changed: \(state)")
    }
    
    func tvClient(didEncounterError error: TVError) async {
        print("⚠️ Error encountered: \(error.localizedDescription)")
    }
    
    func tvClientRequiresPairing() async -> Bool {
        print("📺 Pairing required - Please approve on TV screen")
        print("   Look for a prompt on your Samsung TV")
        print("   Select 'Allow' to grant access")
        // In a real app, you might show a UI dialog here
        return true
    }
}

func exampleWithDelegate() async {
    print("=== SwiftSamsungFrame Delegate Example ===\n")
    
    let device = TVDevice(
        id: "bedroom-tv",
        ipAddress: "192.168.1.101",
        name: "Bedroom TV"
    )
    
    let client = TVClient()
    let delegate = ExampleDelegate()
    
    do {
        print("Connecting with delegate...")
        try await client.connect(to: device, delegate: delegate)
        
        // Connection state changes will be logged via delegate
        
        // Send a command
        try await client.remote.home()
        
        // Wait a bit
        try await Task.sleep(for: .seconds(2))
        
    } catch {
        print("❌ Error: \(error.localizedDescription)")
    }
    
    await client.disconnect()
    print("\n=== Delegate Example Complete ===")
}

/// Example demonstrating error handling patterns
func exampleErrorHandling() async {
    print("=== SwiftSamsungFrame Error Handling Example ===\n")
    
    let device = TVDevice(
        id: "test-tv",
        ipAddress: "192.168.1.999", // Invalid IP to demonstrate error handling
        name: "Test TV"
    )
    
    let client = TVClient()
    
    do {
        try await client.connect(to: device)
    } catch TVError.connectionFailed(let reason) {
        print("Connection failed: \(reason)")
        // Handle connection failure
    } catch TVError.authenticationFailed(let reason) {
        print("Authentication failed: \(reason)")
        // Handle auth failure
    } catch TVError.networkUnreachable {
        print("Network unreachable - check your connection")
        // Handle network issues
    } catch TVError.timeout {
        print("Connection timed out - TV may be off or unreachable")
        // Handle timeout
    } catch {
        print("Unexpected error: \(error)")
        // Handle other errors
    }
    
    print("\n=== Error Handling Example Complete ===")
}

/// Example demonstrating checking connection state
func exampleConnectionState() async {
    print("=== SwiftSamsungFrame Connection State Example ===\n")
    
    let device = TVDevice(
        id: "office-tv",
        ipAddress: "192.168.1.102",
        name: "Office TV"
    )
    
    let client = TVClient()
    
    // Check state before connecting
    let initialState = await client.state
    print("Initial state: \(initialState)")
    
    do {
        try await client.connect(to: device)
        
        // Check state after connecting
        let connectedState = await client.state
        print("Connected state: \(connectedState)")
        
        // Send commands only if authenticated
        if connectedState == .authenticated {
            try await client.remote.volumeUp(steps: 1)
        }
        
    } catch {
        print("Error: \(error)")
    }
    
    await client.disconnect()
    
    // Check state after disconnecting
    let disconnectedState = await client.state
    print("Disconnected state: \(disconnectedState)")
    
    print("\n=== Connection State Example Complete ===")
}

// Note: These examples demonstrate the API usage
// To actually run them, you would need:
// 1. A Samsung TV on your network
// 2. The TV's IP address
// 3. The TV to be powered on
// 4. Network connectivity between your device and the TV
