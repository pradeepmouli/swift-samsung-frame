// Example usage tests for SwiftSamsungFrame
// Demonstrates basic usage patterns

import Testing
import Foundation
@testable import SwiftSamsungFrame

@Test("TVDevice can be created with required properties")
func testTVDeviceCreation() async throws {
    let device = TVDevice(
        id: "test-123",
        host: "192.168.1.100",
        port: 8001,
        name: "Test TV",
        apiVersion: .v2
    )
    
    #expect(device.id == "test-123")
    #expect(device.host == "192.168.1.100")
    #expect(device.port == 8001)
    #expect(device.name == "Test TV")
    #expect(device.apiVersion == .v2)
}

@Test("KeyCode enum provides standard remote control keys")
func testKeyCodeValues() async throws {
    #expect(KeyCode.power.rawValue == "KEY_POWER")
    #expect(KeyCode.volumeUp.rawValue == "KEY_VOLUP")
    #expect(KeyCode.volumeDown.rawValue == "KEY_VOLDOWN")
    #expect(KeyCode.mute.rawValue == "KEY_MUTE")
    #expect(KeyCode.home.rawValue == "KEY_HOME")
}

@Test("NavigationDirection maps to correct key codes")
func testNavigationDirection() async throws {
    #expect(NavigationDirection.up.keyCode == .up)
    #expect(NavigationDirection.down.keyCode == .down)
    #expect(NavigationDirection.left.keyCode == .left)
    #expect(NavigationDirection.right.keyCode == .right)
}

@Test("TVError provides localized descriptions")
func testTVErrorDescriptions() async throws {
    let error1 = TVError.connectionFailed(reason: "Network timeout")
    let error2 = TVError.authenticationRequired
    let error3 = TVError.artModeNotSupported
    
    #expect(error1.localizedDescription.contains("Network timeout"))
    #expect(error2.localizedDescription.contains("Authentication required"))
    #expect(error3.localizedDescription.contains("Art Mode"))
}

@Test("AuthenticationToken validates expiration")
func testTokenExpiration() async throws {
    // Valid token
    let validToken = AuthenticationToken(
        value: "test-token",
        deviceID: "test-device",
        expiresAt: Date().addingTimeInterval(3600)
    )
    #expect(validToken.isValid == true)
    #expect(validToken.isExpired == false)
    
    // Expired token
    let expiredToken = AuthenticationToken(
        value: "expired-token",
        deviceID: "test-device",
        expiresAt: Date().addingTimeInterval(-3600)
    )
    #expect(expiredToken.isExpired == true)
    #expect(expiredToken.isValid == false)
}

@Test("TVClient can be instantiated")
func testTVClientInstantiation() async throws {
    let client = TVClient()
    let state = await client.state
    #expect(state == .disconnected)
}

@Test("WebSocketMessage encodes correctly for remote control")
func testWebSocketMessageEncoding() async throws {
    let message = WebSocketMessage.remoteControl(key: "KEY_POWER")
    let data = try JSONEncoder().encode(message)
    
    #expect(data.count > 0)
    
    // Verify it can be decoded back
    let decoded = try JSONDecoder().decode(WebSocketMessage.self, from: data)
    #expect(decoded.method == "ms.remote.control")
}

@Test("ConnectionState enum is Codable")
func testConnectionStateEncoding() async throws {
    let states: [ConnectionState] = [
        .disconnected,
        .connecting,
        .authenticating,
        .connected,
        .disconnecting,
        .error
    ]
    
    for state in states {
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ConnectionState.self, from: data)
        #expect(decoded == state)
    }
}

@Test("D2DSocketClient can generate connection IDs")
func testD2DSocketClientConnectionID() async throws {
    let id1 = D2DSocketClient.generateConnectionID()
    let id2 = D2DSocketClient.generateConnectionID()
    
    // Verify IDs are generated
    #expect(id1 > 0)
    #expect(id2 > 0)
    
    // Verify IDs are (likely) different
    #expect(id1 != id2)
}

@Test("D2DSocketClient can be instantiated")
func testD2DSocketClientInstantiation() async throws {
    let client = D2DSocketClient()
    
    // Verify client can be used (compilation check for cancel method)
    await client.cancel()
}
