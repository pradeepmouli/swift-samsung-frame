// TVApp - Represents an installed TV application
// Contains app metadata and running status

import Foundation

/// Represents an installed application on the TV
public struct TVApp: Sendable, Identifiable, Hashable, Codable {
    /// Unique app identifier
    public let id: String
    
    /// Display name
    public let name: String
    
    /// App version
    public let version: String?
    
    /// Icon image URL
    public let iconURL: URL?
    
    /// Current execution state
    public let isRunning: Bool
    
    /// Last launch timestamp
    public let lastLaunched: Date?
    
    /// Initialize a new TV app
    /// - Parameters:
    ///   - id: Unique app identifier
    ///   - name: Display name
    ///   - version: App version
    ///   - iconURL: Icon image URL
    ///   - isRunning: Current execution state
    ///   - lastLaunched: Last launch timestamp
    public init(
        id: String,
        name: String,
        version: String? = nil,
        iconURL: URL? = nil,
        isRunning: Bool = false,
        lastLaunched: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.iconURL = iconURL
        self.isRunning = isRunning
        self.lastLaunched = lastLaunched
    }
}

// MARK: - Example for Testing

extension TVApp {
    /// Example app for testing purposes
    public static let example = TVApp(
        id: "111299001912",
        name: "YouTube",
        version: "1.0.0",
        iconURL: URL(string: "https://example.com/icon.png"),
        isRunning: false,
        lastLaunched: nil
    )
}
