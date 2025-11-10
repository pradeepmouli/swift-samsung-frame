// DiscoveryService - Network device discovery for Samsung TVs
// Implements mDNS and SSDP discovery protocols

import Foundation

#if canImport(OSLog)
import OSLog
#endif

/// Service for discovering Samsung TVs on the local network
public final class DiscoveryService: DiscoveryServiceProtocol, @unchecked Sendable {
    private var mdnsBrowser: MDNSBrowser?
    private var ssdpBrowser: SSDPBrowser?
    private var isDiscovering = false
    private var discoveryTask: Task<Void, Never>?
    
    public init() {}
    
    /// Discover TVs on local network
    /// - Parameter timeout: Discovery timeout duration (default: 10 seconds)
    /// - Returns: AsyncStream of discovered devices
    public func discover(timeout: Duration = .seconds(10)) -> AsyncStream<DiscoveryResult> {
        return AsyncStream { continuation in
            // Cancel any existing discovery
            self.cancel()
            
            // Start new discovery task
            self.discoveryTask = Task {
                await self.startDiscovery(timeout: timeout, continuation: continuation)
            }
        }
    }
    
    /// Start discovery process with mDNS first, then SSDP fallback
    private func startDiscovery(
        timeout: Duration,
        continuation: AsyncStream<DiscoveryResult>.Continuation
    ) async {
        guard !isDiscovering else { return }
        
        isDiscovering = true
        mdnsBrowser = MDNSBrowser()
        ssdpBrowser = SSDPBrowser()
        
        #if canImport(OSLog)
        Logger.discovery.info("Starting TV discovery with \(timeout.seconds())s timeout")
        #endif
        
        // Discovery strategy: mDNS first (3s), then SSDP for remaining time
        let mdnsTimeout = Duration.seconds(3)
        let remainingTime = timeout.seconds() - mdnsTimeout.seconds()
        let ssdpTimeout = Duration.seconds(max(0, remainingTime))
        
        // Phase 1: Try mDNS first (best for Frame TVs and modern Samsung TVs)
        if let mdnsBrowser {
            #if canImport(OSLog)
            Logger.discovery.debug("Phase 1: mDNS discovery (\(mdnsTimeout.seconds())s)")
            #endif
            
            await mdnsBrowser.discover(timeout: mdnsTimeout, continuation: continuation)
        }
        
        // Phase 2: Try SSDP for remaining time (fallback for older models)
        if ssdpTimeout.seconds() > 0, let ssdpBrowser {
            #if canImport(OSLog)
            Logger.discovery.debug("Phase 2: SSDP discovery (\(ssdpTimeout.seconds())s)")
            #endif
            
            await ssdpBrowser.discover(timeout: ssdpTimeout, continuation: continuation)
        }
        
        isDiscovering = false
        continuation.finish()
        
        #if canImport(OSLog)
        Logger.discovery.info("TV discovery completed")
        #endif
    }
    
    /// Cancel ongoing discovery
    public func cancel() {
        #if canImport(OSLog)
        Logger.discovery.info("Cancelling TV discovery")
        #endif
        
        discoveryTask?.cancel()
        discoveryTask = nil
        isDiscovering = false
        
        Task {
            await mdnsBrowser?.stop()
            await ssdpBrowser?.stop()
            mdnsBrowser = nil
            ssdpBrowser = nil
        }
    }
    
    /// Quick scan for specific TV at known IP address
    /// - Parameter host: Known IP address to check
    /// - Returns: Discovery result if TV found
    /// - Throws: TVError.deviceNotFound
    public func find(at host: String) async throws -> DiscoveryResult {
        #if canImport(OSLog)
        Logger.discovery.debug("Checking for TV at: \(host)")
        #endif
        
        // Try to connect to the REST API to verify it's a Samsung TV
        let baseURL = URL(string: "http://\(host):8001")!
        let restClient = RESTClient(baseURL: baseURL)
        
        do {
            let data = try await restClient.getDeviceInfo()
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let device = json["device"] as? [String: Any],
               let name = device["name"] as? String,
               let modelName = device["modelName"] as? String {
                
                #if canImport(OSLog)
                Logger.discovery.info("Found Samsung TV at \(host): \(name) (\(modelName))")
                #endif
                
                return DiscoveryResult(
                    device: TVDevice(
                        id: host,
                        host: host,
                        port: 8001,
                        name: name,
                        modelName: modelName,
                        apiVersion: .v2
                    ),
                    discoveryMethod: .manual
                )
            }
            
            throw TVError.deviceNotFound(id: host)
        } catch {
            #if canImport(OSLog)
            Logger.discovery.error("No Samsung TV found at \(host): \(error.localizedDescription)")
            #endif
            
            throw TVError.deviceNotFound(id: host)
        }
    }
}
