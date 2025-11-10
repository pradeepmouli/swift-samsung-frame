import Foundation

#if canImport(os)
import os

extension Logger {
    /// Logger subsystem identifier
    private static let subsystem = "com.swiftsamsungframe"
    
    /// Logger for connection-related events
    public static let connection = Logger(subsystem: subsystem, category: "connection")
    
    /// Logger for command execution
    public static let commands = Logger(subsystem: subsystem, category: "commands")
    
    /// Logger for app management
    public static let apps = Logger(subsystem: subsystem, category: "apps")
    
    /// Logger for art mode operations
    public static let art = Logger(subsystem: subsystem, category: "art")
    
    /// Logger for device discovery
    public static let discovery = Logger(subsystem: subsystem, category: "discovery")
    
    /// Logger for networking operations
    public static let networking = Logger(subsystem: subsystem, category: "networking")
}
#endif
