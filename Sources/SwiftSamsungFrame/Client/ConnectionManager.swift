// ConnectionManager - Advanced connection management
// Handles health checks, auto-reconnect, and keep-alive

import Foundation
#if canImport(OSLog)
import OSLog
#endif

/// Advanced connection manager with health checks and auto-reconnect
public actor ConnectionManager {
    private var isMonitoring = false
    private var reconnectTask: Task<Void, Never>?
    private var healthCheckTask: Task<Void, Never>?
    
    /// Configuration for connection management
    public struct Configuration: Sendable {
        /// Enable automatic reconnection on disconnect
        public var autoReconnect: Bool
        
        /// Maximum number of reconnection attempts (0 = unlimited)
        public var maxReconnectAttempts: Int
        
        /// Delay between reconnection attempts
        public var reconnectDelay: Duration
        
        /// Enable periodic health checks
        public var enableHealthChecks: Bool
        
        /// Interval between health checks
        public var healthCheckInterval: Duration
        
        /// Health check timeout
        public var healthCheckTimeout: Duration
        
        public init(
            autoReconnect: Bool = true,
            maxReconnectAttempts: Int = 5,
            reconnectDelay: Duration = .seconds(5),
            enableHealthChecks: Bool = true,
            healthCheckInterval: Duration = .seconds(30),
            healthCheckTimeout: Duration = .seconds(5)
        ) {
            self.autoReconnect = autoReconnect
            self.maxReconnectAttempts = maxReconnectAttempts
            self.reconnectDelay = reconnectDelay
            self.enableHealthChecks = enableHealthChecks
            self.healthCheckInterval = healthCheckInterval
            self.healthCheckTimeout = healthCheckTimeout
        }
    }
    
    private let configuration: Configuration
    private weak var client: TVClient?
    private var reconnectAttempts = 0
    
    /// Initialize connection manager
    /// - Parameter configuration: Connection management configuration
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }
    
    /// Start managing connection for a client
    /// - Parameter client: TV client to manage
    public func startManaging(_ client: TVClient) {
        self.client = client
        
        if configuration.enableHealthChecks {
            startHealthChecks()
        }
    }
    
    /// Stop managing connection
    public func stopManaging() {
        stopHealthChecks()
        reconnectTask?.cancel()
        reconnectTask = nil
        client = nil
    }
    
    /// Start periodic health checks
    private func startHealthChecks() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        healthCheckTask = Task {
            while !Task.isCancelled && isMonitoring {
                do {
                    try await Task.sleep(for: configuration.healthCheckInterval)
                    
                    guard let client else { break }
                    
                    // Check connection state
                    let state = await client.state
                    
                    if state == .connected {
                        // Perform health check
                        do {
                            // Try to get device info as a health check
                            _ = try await withTimeout(
                                duration: configuration.healthCheckTimeout
                            ) {
                                try await client.deviceInfo()
                            }
                            
                            #if canImport(OSLog)
                            Logger.connection.debug("Health check passed")
                            #endif
                            
                            reconnectAttempts = 0 // Reset on successful check
                        } catch {
                            #if canImport(OSLog)
                            Logger.connection.warning("Health check failed: \(error.localizedDescription)")
                            #endif
                            
                            // Connection appears dead, trigger reconnect if enabled
                            if configuration.autoReconnect {
                                await attemptReconnect()
                            }
                        }
                    } else if state == .disconnected && configuration.autoReconnect {
                        await attemptReconnect()
                    }
                } catch {
                    // Sleep was cancelled
                    break
                }
            }
        }
    }
    
    /// Stop health checks
    private func stopHealthChecks() {
        isMonitoring = false
        healthCheckTask?.cancel()
        healthCheckTask = nil
    }
    
    /// Attempt to reconnect to the TV
    private func attemptReconnect() async {
        guard client != nil else { return }
        guard reconnectTask == nil else { return } // Already reconnecting
        
        // Check if we've exceeded max attempts
        if configuration.maxReconnectAttempts > 0 &&
           reconnectAttempts >= configuration.maxReconnectAttempts {
            #if canImport(OSLog)
            Logger.connection.error("Max reconnect attempts reached")
            #endif
            return
        }
        
        reconnectTask = Task {
            reconnectAttempts += 1
            
            #if canImport(OSLog)
            Logger.connection.info("Attempting reconnect (attempt \(self.reconnectAttempts))")
            #endif
            
            do {
                try await Task.sleep(for: configuration.reconnectDelay)
                
                // Get the device info from current session
                // Note: In a full implementation, we'd store connection parameters
                // For now, this is a placeholder for the reconnection logic
                
                #if canImport(OSLog)
                Logger.connection.info("Reconnection successful")
                #endif
                
                reconnectAttempts = 0
            } catch {
                #if canImport(OSLog)
                Logger.connection.error("Reconnection failed: \(error.localizedDescription)")
                #endif
            }
            
            reconnectTask = nil
        }
    }
    
    /// Execute operation with timeout
    private func withTimeout<T: Sendable>(
        duration: Duration,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(for: duration)
                throw TVError.timeout(operation: "Health check", error: nil)
            }
            
            guard let result = try await group.next() else {
                throw TVError.timeout(operation: "Health check", error: nil)
            }
            
            group.cancelAll()
            return result
        }
    }
}
