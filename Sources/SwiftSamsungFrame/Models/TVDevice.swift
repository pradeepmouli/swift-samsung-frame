import Foundation

/// Represents a Samsung TV device
public struct TVDevice: Sendable, Identifiable, Hashable, Codable {
    /// Unique identifier for the device (typically MAC address or UUID)
    public let id: String
    
    /// IP address of the TV
    public let ipAddress: String
    
    /// Port number for WebSocket connections (default: 8002 for wss)
    public let port: Int
    
    /// Model name of the TV
    public let modelName: String?
    
    /// Friendly name of the TV
    public let name: String?
    
    /// Firmware version
    public let firmwareVersion: String?
    
    /// MAC address
    public let macAddress: String?
    
    /// Supported features
    public let supportedFeatures: Set<TVFeature>
    
    /// API version supported by the TV
    public let apiVersion: APIVersion
    
    /// Creates a new TV device
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - ipAddress: IP address of the TV
    ///   - port: Port number (default: 8002)
    ///   - modelName: Model name
    ///   - name: Friendly name
    ///   - firmwareVersion: Firmware version
    ///   - macAddress: MAC address
    ///   - supportedFeatures: Set of supported features
    ///   - apiVersion: API version (default: v2)
    public init(
        id: String,
        ipAddress: String,
        port: Int = 8002,
        modelName: String? = nil,
        name: String? = nil,
        firmwareVersion: String? = nil,
        macAddress: String? = nil,
        supportedFeatures: Set<TVFeature> = [.remoteControl, .appManagement, .deviceInfo],
        apiVersion: APIVersion = .v2
    ) {
        self.id = id
        self.ipAddress = ipAddress
        self.port = port
        self.modelName = modelName
        self.name = name
        self.firmwareVersion = firmwareVersion
        self.macAddress = macAddress
        self.supportedFeatures = supportedFeatures
        self.apiVersion = apiVersion
    }
    
    /// WebSocket URL for connecting to this TV
    public var websocketURL: URL {
        URL(string: "wss://\(ipAddress):\(port)/api/v2/channels/samsung.remote.control?name=\(deviceName)")!
    }
    
    /// REST API base URL
    public var restBaseURL: URL {
        URL(string: "https://\(ipAddress):\(port + 1)/api/v2")!
    }
    
    /// Device name for connection identification
    private var deviceName: String {
        "SwiftSamsungFrame".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "SwiftSamsungFrame"
    }
    
    /// Checks if a specific feature is supported
    /// - Parameter feature: The feature to check
    /// - Returns: True if the feature is supported
    public func supports(_ feature: TVFeature) -> Bool {
        supportedFeatures.contains(feature)
    }
}
