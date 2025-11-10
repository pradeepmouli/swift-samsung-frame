// SSDPBrowser - SSDP/UPnP discovery for Samsung TVs
// Implements SSDP M-SEARCH for discovering TVs on the network

import Foundation

#if canImport(Network)
import Network

#if canImport(OSLog)
import OSLog
#endif

/// Browser for discovering Samsung TVs via SSDP/UPnP
actor SSDPBrowser {
    private var connection: NWConnection?
    private var isScanning = false
    private var discoveredDevices: [String: DiscoveryResult] = [:]
    
    /// Start SSDP discovery for Samsung TVs
    /// - Parameters:
    ///   - timeout: Discovery timeout duration
    ///   - continuation: AsyncStream continuation to emit results
    func discover(timeout: Duration, continuation: AsyncStream<DiscoveryResult>.Continuation) async {
        guard !isScanning else { return }
        
        isScanning = true
        discoveredDevices.removeAll()
        
        #if canImport(OSLog)
        Logger.discovery.info("Starting SSDP discovery for Samsung TVs")
        #endif
        
        // SSDP multicast address and port
        let multicastGroup = NWEndpoint.hostPort(
            host: NWEndpoint.Host("239.255.255.250"),
            port: NWEndpoint.Port(integerLiteral: 1900)
        )
        
        // Create UDP connection
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        
        connection = NWConnection(to: multicastGroup, using: parameters)
        
        // Set up state handler
        connection?.stateUpdateHandler = { [weak self] state in
            Task {
                await self?.handleStateChange(state)
            }
        }
        
        // Start connection
        let queue = DispatchQueue(label: "com.swiftsamsungframe.ssdp")
        connection?.start(queue: queue)
        
        // Wait a moment for connection to be ready
        try? await Task.sleep(for: .milliseconds(500))
        
        // Send M-SEARCH request
        await sendMSearch()
        
        // Start receiving responses
        await receiveResponses(continuation: continuation)
        
        // Wait for timeout
        do {
            try await Task.sleep(for: timeout)
        } catch {
            // Cancelled
        }
        
        // Stop scanning
        await stop()
        
        #if canImport(OSLog)
        Logger.discovery.info("SSDP discovery completed. Found \(self.discoveredDevices.count) devices")
        #endif
    }
    
    /// Stop SSDP discovery
    func stop() async {
        connection?.cancel()
        connection = nil
        isScanning = false
    }
    
    /// Handle connection state changes
    private func handleStateChange(_ state: NWConnection.State) {
        #if canImport(OSLog)
        switch state {
        case .ready:
            Logger.discovery.debug("SSDP connection ready")
        case .failed(let error):
            Logger.discovery.error("SSDP connection failed: \(error.localizedDescription)")
        case .cancelled:
            Logger.discovery.debug("SSDP connection cancelled")
        default:
            break
        }
        #endif
    }
    
    /// Send SSDP M-SEARCH request
    private func sendMSearch() async {
        guard let connection else { return }
        
        // M-SEARCH message targeting Samsung RemoteControlReceiver
        let mSearchMessage = """
        M-SEARCH * HTTP/1.1\r
        HOST: 239.255.255.250:1900\r
        MAN: "ssdp:discover"\r
        MX: 3\r
        ST: urn:samsung.com:device:RemoteControlReceiver:1\r
        \r
        """
        
        guard let data = mSearchMessage.data(using: .utf8) else { return }
        
        #if canImport(OSLog)
        Logger.discovery.debug("Sending SSDP M-SEARCH request")
        #endif
        
        connection.send(content: data, completion: .contentProcessed { error in
            if let error {
                #if canImport(OSLog)
                Logger.discovery.error("Failed to send M-SEARCH: \(error.localizedDescription)")
                #endif
            }
        })
    }
    
    /// Receive SSDP responses
    private func receiveResponses(continuation: AsyncStream<DiscoveryResult>.Continuation) async {
        guard let connection else { return }
        
        // Keep receiving until stopped
        while isScanning {
            await withCheckedContinuation { innerContinuation in
                connection.receiveMessage { [weak self] content, _, _, error in
                    guard let self else {
                        innerContinuation.resume()
                        return
                    }
                    
                    if let error {
                        #if canImport(OSLog)
                        Logger.discovery.debug("SSDP receive error: \(error.localizedDescription)")
                        #endif
                        innerContinuation.resume()
                        return
                    }
                    
                    if let content, let response = String(data: content, encoding: .utf8) {
                        Task { [weak self] in
                            guard let self else { return }
                            await self.processResponse(response, continuation: continuation)
                        }
                    }
                    
                    innerContinuation.resume()
                }
            }
            
            // Small delay between receives
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
    
    /// Process SSDP response
    private func processResponse(
        _ response: String,
        continuation: AsyncStream<DiscoveryResult>.Continuation
    ) async {
        #if canImport(OSLog)
        Logger.discovery.debug("Received SSDP response")
        #endif
        
        // Parse response headers
        let lines = response.components(separatedBy: "\r\n")
        var location: String?
        var server: String?
        
        for line in lines {
            let parts = line.components(separatedBy: ": ")
            guard parts.count == 2 else { continue }
            
            let key = parts[0].uppercased()
            let value = parts[1]
            
            if key == "LOCATION" {
                location = value
            } else if key == "SERVER" {
                server = value
            }
        }
        
        // Extract host from location URL
        guard let location,
              let url = URL(string: location),
              let host = url.host else {
            return
        }
        
        #if canImport(OSLog)
        Logger.discovery.info("Found Samsung TV via SSDP at: \(host)")
        #endif
        
        // Create discovery result
        let device = TVDevice(
            id: host,
            host: host,
            port: 8001, // Standard Samsung TV port
            name: "Samsung TV",
            modelName: server ?? "Unknown",
            apiVersion: .v2
        )
        
        let discoveryResult = DiscoveryResult(
            device: device,
            discoveryMethod: .ssdp
        )
        
        await handleDiscovery(discoveryResult, continuation: continuation)
    }
    
    /// Handle a discovered device
    private func handleDiscovery(
        _ result: DiscoveryResult,
        continuation: AsyncStream<DiscoveryResult>.Continuation
    ) async {
        let deviceId = result.device.id
        
        // Avoid duplicates
        guard discoveredDevices[deviceId] == nil else {
            return
        }
        
        discoveredDevices[deviceId] = result
        continuation.yield(result)
    }
}

#else
// Stub for platforms without Network framework
actor SSDPBrowser {
    func discover(timeout: Duration, continuation: AsyncStream<DiscoveryResult>.Continuation) async {
        #if canImport(OSLog)
        Logger.discovery.warning("SSDP discovery not available on this platform")
        #endif
    }
    
    func stop() async {}
}
#endif
