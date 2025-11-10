import Foundation

/// Result from device discovery
public struct DiscoveryResult: Sendable {
    /// Discovered TV device
    public let device: TVDevice
    
    /// Discovery method used
    public let method: DiscoveryMethod
    
    /// When the device was discovered
    public let discoveredAt: Date
    
    /// Signal strength or confidence (0.0 to 1.0)
    public let signalStrength: Double?
    
    /// Creates a new discovery result
    /// - Parameters:
    ///   - device: Discovered TV device
    ///   - method: Discovery method used
    ///   - discoveredAt: Discovery timestamp (default: now)
    ///   - signalStrength: Signal strength (optional)
    public init(
        device: TVDevice,
        method: DiscoveryMethod,
        discoveredAt: Date = Date(),
        signalStrength: Double? = nil
    ) {
        self.device = device
        self.method = method
        self.discoveredAt = discoveredAt
        self.signalStrength = signalStrength
    }
}
