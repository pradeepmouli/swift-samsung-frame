import Foundation

/// Represents an installed TV application
public struct TVApp: Sendable, Identifiable, Hashable, Codable {
    /// Unique application ID
    public let id: String
    
    /// Application name
    public let name: String
    
    /// Application version
    public let version: String?
    
    /// Application icon URL
    public let iconURL: URL?
    
    /// Current running status
    public let status: AppStatus
    
    /// Creates a new TV application
    /// - Parameters:
    ///   - id: Application ID
    ///   - name: Application name
    ///   - version: Application version
    ///   - iconURL: Icon URL
    ///   - status: Current status (default: unknown)
    public init(
        id: String,
        name: String,
        version: String? = nil,
        iconURL: URL? = nil,
        status: AppStatus = .unknown
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.iconURL = iconURL
        self.status = status
    }
}
