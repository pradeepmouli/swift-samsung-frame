// TVDevice - Represents a Samsung TV device
// Contains device information and capabilities

import Foundation

/// Represents a Samsung TV discovered or connected to the network
public struct TVDevice: Sendable, Identifiable, Hashable, Codable {
    /// Unique identifier (derived from MAC address or UUID)
    public let id: String
    
    /// IP address or hostname
    public let host: String
    
    /// WebSocket port (default: 8001)
    public let port: Int
    
    /// Friendly device name (e.g., "Living Room TV")
    public let name: String
    
    /// TV model identifier (e.g., "UN55LS03RAFXZA")
    public let modelName: String?
    
    /// Current firmware version
    public let firmwareVersion: String?
    
    /// MAC address for Wake-on-LAN
    public let macAddress: String?
    
    /// Capabilities (art mode, voice control, etc.)
    public let supportedFeatures: Set<TVFeature>
    
    /// Supported API version (v1, v2)
    public let apiVersion: APIVersion
    
    /// Initialize a new TV device
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - host: IP address or hostname
    ///   - port: WebSocket port (default: 8001)
    ///   - name: Friendly device name
    ///   - modelName: TV model identifier
    ///   - firmwareVersion: Current firmware version
    ///   - macAddress: MAC address
    ///   - supportedFeatures: Device capabilities
    ///   - apiVersion: Supported API version
    public init(
        id: String,
        host: String,
        port: Int = 8001,
        name: String,
        modelName: String? = nil,
        firmwareVersion: String? = nil,
        macAddress: String? = nil,
        supportedFeatures: Set<TVFeature> = [],
        apiVersion: APIVersion = .v2
    ) {
        self.id = id
        self.host = host
        self.port = port
        self.name = name
        self.modelName = modelName
        self.firmwareVersion = firmwareVersion
        self.macAddress = macAddress
        self.supportedFeatures = supportedFeatures
        self.apiVersion = apiVersion
    }
}

// MARK: - Example for Testing

extension TVDevice {
    /// Example TV device for testing and preview purposes
    public static let example = TVDevice(
        id: "example-tv",
        host: "192.168.1.100",
        port: 8001,
        name: "Living Room TV",
        modelName: "UN55LS03RAFXZA",
        firmwareVersion: "1.0.0",
        macAddress: "00:11:22:33:44:55",
        supportedFeatures: [.artMode, .voiceControl],
        apiVersion: .v2
    )
}
