// Logger Extensions - OSLog categories for Samsung TV Client
// Provides structured logging for different components

#if canImport(OSLog)
import OSLog

extension Logger {
    /// Logger for connection lifecycle events
    public static let connection = Logger(subsystem: "com.swiftsamsungframe", category: "connection")
    
    /// Logger for remote control commands
    public static let commands = Logger(subsystem: "com.swiftsamsungframe", category: "commands")
    
    /// Logger for app management operations
    public static let apps = Logger(subsystem: "com.swiftsamsungframe", category: "apps")
    
    /// Logger for art mode operations
    public static let art = Logger(subsystem: "com.swiftsamsungframe", category: "art")
    
    /// Logger for device discovery
    public static let discovery = Logger(subsystem: "com.swiftsamsungframe", category: "discovery")
    
    /// Logger for networking operations
    public static let networking = Logger(subsystem: "com.swiftsamsungframe", category: "networking")
}
#endif
