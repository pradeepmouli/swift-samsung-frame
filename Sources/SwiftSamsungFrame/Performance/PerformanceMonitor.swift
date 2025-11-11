// PerformanceMonitor - Performance measurement utilities
// Provides timing and instrumentation for TV operations

import Foundation

#if canImport(OSLog)
import OSLog
#endif

#if canImport(os.signpost)
import os.signpost
#endif

/// Performance monitoring utilities for measuring operation timing
public struct PerformanceMonitor: Sendable {
    
    // MARK: - Timing Utilities
    
    /// Measure the execution time of an async operation
    /// - Parameters:
    ///   - label: Description of the operation being measured
    ///   - operation: The async operation to measure
    /// - Returns: Tuple of (result, duration in seconds)
    /// - Throws: Rethrows any error from the operation
    public static func measure<T>(
        _ label: String,
        operation: () async throws -> T
    ) async rethrows -> (result: T, duration: TimeInterval) {
        let clock = ContinuousClock()
        let start = clock.now
        
        let result = try await operation()
        
        let end = clock.now
        let duration = start.duration(to: end)
        let seconds = Double(duration.components.seconds) + 
                     Double(duration.components.attoseconds) / 1_000_000_000_000_000_000.0
        
        #if canImport(OSLog)
        Logger.networking.info("⏱️ \(label) completed in \(String(format: "%.3f", seconds))s")
        #else
        print("⏱️ \(label) completed in \(String(format: "%.3f", seconds))s")
        #endif
        
        return (result, seconds)
    }
    
    /// Measure execution time and log if it exceeds threshold
    /// - Parameters:
    ///   - label: Description of the operation
    ///   - threshold: Warning threshold in seconds
    ///   - operation: The async operation to measure
    /// - Returns: The operation result
    /// - Throws: Rethrows any error from the operation
    public static func measureWithThreshold<T>(
        _ label: String,
        threshold: TimeInterval = 1.0,
        operation: () async throws -> T
    ) async rethrows -> T {
        let (result, duration) = try await measure(label, operation: operation)
        
        if duration > threshold {
            #if canImport(OSLog)
            Logger.networking.warning("⚠️ \(label) exceeded threshold: \(String(format: "%.3f", duration))s (threshold: \(String(format: "%.3f", threshold))s)")
            #else
            print("⚠️ \(label) exceeded threshold: \(String(format: "%.3f", duration))s (threshold: \(String(format: "%.3f", threshold))s)")
            #endif
        }
        
        return result
    }
    
    /// Time an operation and return only the duration
    /// - Parameter operation: The operation to time
    /// - Returns: Duration in seconds
    public static func time(
        operation: () async throws -> Void
    ) async rethrows -> TimeInterval {
        let clock = ContinuousClock()
        let start = clock.now
        
        try await operation()
        
        let end = clock.now
        let duration = start.duration(to: end)
        return Double(duration.components.seconds) + 
               Double(duration.components.attoseconds) / 1_000_000_000_000_000_000.0
    }
}

// MARK: - OSLog Signpost Support

#if canImport(os.signpost)
/// Signpost-based performance instrumentation
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct SignpostMonitor {
    private static let log = OSLog(subsystem: "com.swiftsamsungframe", category: .pointsOfInterest)
    
    /// Execute an operation with signpost instrumentation
    /// - Parameters:
    ///   - name: Signpost name
    ///   - operation: The operation to instrument
    /// - Returns: The operation result
    /// - Throws: Rethrows any error from the operation
    public static func trace<T>(
        _ name: StaticString,
        operation: () async throws -> T
    ) async rethrows -> T {
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: signpostID)
        
        defer {
            os_signpost(.end, log: log, name: name, signpostID: signpostID)
        }
        
        return try await operation()
    }
    
    /// Mark a specific point in time with metadata
    /// - Parameters:
    ///   - name: Event name
    ///   - message: Optional message describing the event
    public static func event(_ name: StaticString, _ message: String? = nil) {
        if let message {
            os_signpost(.event, log: log, name: name, "%{public}s", message)
        } else {
            os_signpost(.event, log: log, name: name)
        }
    }
    
    /// Begin an interval signpost
    /// - Parameter name: Interval name
    /// - Returns: Signpost ID for ending the interval
    public static func beginInterval(_ name: StaticString) -> OSSignpostID {
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: signpostID)
        return signpostID
    }
    
    /// End an interval signpost
    /// - Parameters:
    ///   - name: Interval name
    ///   - signpostID: ID returned from beginInterval
    public static func endInterval(_ name: StaticString, _ signpostID: OSSignpostID) {
        os_signpost(.end, log: log, name: name, signpostID: signpostID)
    }
}
#endif

// MARK: - Operation Timer

/// Tracks timing statistics for named operations
public actor OperationTimer {
    private var timings: [String: [TimeInterval]] = [:]
    
    public init() {}
    
    /// Record a timing for an operation
    /// - Parameters:
    ///   - operation: Operation name
    ///   - duration: Duration in seconds
    public func record(_ operation: String, duration: TimeInterval) {
        timings[operation, default: []].append(duration)
    }
    
    /// Get statistics for an operation
    /// - Parameter operation: Operation name
    /// - Returns: Statistics (count, min, max, avg, total)
    public func statistics(for operation: String) -> OperationStats? {
        guard let durations = timings[operation], !durations.isEmpty else {
            return nil
        }
        
        return OperationStats(
            operation: operation,
            count: durations.count,
            min: durations.min() ?? 0,
            max: durations.max() ?? 0,
            average: durations.reduce(0, +) / Double(durations.count),
            total: durations.reduce(0, +)
        )
    }
    
    /// Get all recorded statistics
    /// - Returns: Dictionary of operation stats
    public func allStatistics() -> [String: OperationStats] {
        var stats: [String: OperationStats] = [:]
        for (operation, durations) in timings where !durations.isEmpty {
            stats[operation] = OperationStats(
                operation: operation,
                count: durations.count,
                min: durations.min() ?? 0,
                max: durations.max() ?? 0,
                average: durations.reduce(0, +) / Double(durations.count),
                total: durations.reduce(0, +)
            )
        }
        return stats
    }
    
    /// Clear all recorded timings
    public func reset() {
        timings.removeAll()
    }
    
    /// Clear timings for a specific operation
    /// - Parameter operation: Operation name
    public func reset(_ operation: String) {
        timings.removeValue(forKey: operation)
    }
}

/// Statistics for an operation
public struct OperationStats: Sendable, Codable {
    /// Operation name
    public let operation: String
    
    /// Number of executions
    public let count: Int
    
    /// Minimum duration (seconds)
    public let min: TimeInterval
    
    /// Maximum duration (seconds)
    public let max: TimeInterval
    
    /// Average duration (seconds)
    public let average: TimeInterval
    
    /// Total duration (seconds)
    public let total: TimeInterval
    
    /// Format as human-readable string
    public var description: String {
        """
        \(operation):
          Count: \(count)
          Min: \(String(format: "%.3f", min))s
          Max: \(String(format: "%.3f", max))s
          Avg: \(String(format: "%.3f", average))s
          Total: \(String(format: "%.3f", total))s
        """
    }
}

// MARK: - Performance Macros

extension PerformanceMonitor {
    /// Measure connection-related operations
    public static func measureConnection<T>(
        _ label: String,
        operation: () async throws -> T
    ) async rethrows -> T {
        #if canImport(os.signpost)
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) {
            return try await SignpostMonitor.trace("Connection: \(label)") {
                try await measureWithThreshold(label, threshold: 5.0, operation: operation)
            }
        }
        #endif
        return try await measureWithThreshold(label, threshold: 5.0, operation: operation)
    }
    
    /// Measure command execution
    public static func measureCommand<T>(
        _ label: String,
        operation: () async throws -> T
    ) async rethrows -> T {
        #if canImport(os.signpost)
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) {
            return try await SignpostMonitor.trace("Command: \(label)") {
                try await measureWithThreshold(label, threshold: 1.0, operation: operation)
            }
        }
        #endif
        return try await measureWithThreshold(label, threshold: 1.0, operation: operation)
    }
    
    /// Measure discovery operations
    public static func measureDiscovery<T>(
        _ label: String,
        operation: () async throws -> T
    ) async rethrows -> T {
        #if canImport(os.signpost)
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) {
            return try await SignpostMonitor.trace("Discovery: \(label)") {
                try await measureWithThreshold(label, threshold: 10.0, operation: operation)
            }
        }
        #endif
        return try await measureWithThreshold(label, threshold: 10.0, operation: operation)
    }
    
    /// Measure art-related operations
    public static func measureArt<T>(
        _ label: String,
        operation: () async throws -> T
    ) async rethrows -> T {
        #if canImport(os.signpost)
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) {
            return try await SignpostMonitor.trace("Art: \(label)") {
                try await measureWithThreshold(label, threshold: 3.0, operation: operation)
            }
        }
        #endif
        return try await measureWithThreshold(label, threshold: 3.0, operation: operation)
    }
}

// MARK: - Usage Examples

/*
 Example usage:
 
 // Basic timing
 let (device, duration) = await PerformanceMonitor.measure("Get Device Info") {
     try await client.deviceInfo()
 }
 print("Got device info in \(duration)s")
 
 // With threshold warning
 let result = await PerformanceMonitor.measureWithThreshold(
     "Connect to TV",
     threshold: 2.0
 ) {
     try await client.connect(to: "192.168.1.100")
 }
 
 // Using signposts (macOS 15+, iOS 18+)
 if #available(macOS 15.0, iOS 18.0, *) {
     let result = await SignpostMonitor.trace("WebSocket Send") {
         try await websocket.send(message)
     }
     
     SignpostMonitor.event("Device Connected", "IP: 192.168.1.100")
     
     let id = SignpostMonitor.beginInterval("Long Operation")
     // ... do work ...
     SignpostMonitor.endInterval("Long Operation", id)
 }
 
 // Track operation statistics
 let timer = OperationTimer()
 for _ in 0..<10 {
     let duration = await PerformanceMonitor.time {
         try await client.remote.power()
     }
     await timer.record("Power Command", duration: duration)
 }
 
 if let stats = await timer.statistics(for: "Power Command") {
     print(stats.description)
 }
 
 // Category-specific measurements
 let device = await PerformanceMonitor.measureConnection("Initial Connection") {
     try await client.connect(to: host)
 }
 
 await PerformanceMonitor.measureCommand("Volume Up") {
     try await client.remote.volumeUp()
 }
 
 let tvs = await PerformanceMonitor.measureDiscovery("Network Scan") {
     try await discovery.discover()
 }
 */
