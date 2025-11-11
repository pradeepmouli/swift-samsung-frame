// DiscoveryResult - Represents a discovered TV on the network
// Contains device information and discovery metadata

import Foundation

/// Represents a discovered TV on the network
public struct DiscoveryResult: Sendable, Identifiable {
    /// Discovered device information
    public let device: TVDevice
    
    /// How it was found (SSDP, mDNS)
    public let discoveryMethod: DiscoveryMethod
    
    /// When discovered
    public let discoveredAt: Date
    
    /// Network signal quality (0-100)
    public let signalStrength: Int?
    
    /// Whether device responds to ping
    public let isReachable: Bool
    
    /// Use device ID for identifiable conformance
    public var id: String { device.id }
    
    /// Initialize a new discovery result
    /// - Parameters:
    ///   - device: Discovered device
    ///   - discoveryMethod: Discovery method used
    ///   - discoveredAt: Discovery timestamp
    ///   - signalStrength: Network signal quality (0-100)
    ///   - isReachable: Whether device is reachable
    public init(
        device: TVDevice,
        discoveryMethod: DiscoveryMethod,
        discoveredAt: Date = Date(),
        signalStrength: Int? = nil,
        isReachable: Bool = true
    ) {
        if let strength = signalStrength {
            precondition((0...100).contains(strength), "Signal strength must be 0-100")
        }
        self.device = device
        self.discoveryMethod = discoveryMethod
        self.discoveredAt = discoveredAt
        self.signalStrength = signalStrength
        self.isReachable = isReachable
    }
}
