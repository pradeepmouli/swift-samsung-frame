// MDNSBrowser - mDNS/Bonjour discovery for Samsung TVs
// Uses Network framework's NWBrowser for service discovery

import Foundation

#if canImport(Network)
import Network

#if canImport(OSLog)
import OSLog
#endif

/// Browser for discovering Samsung TVs via mDNS/Bonjour
actor MDNSBrowser {
    private var browser: NWBrowser?
    private var isScanning = false
    private var discoveredDevices: [String: DiscoveryResult] = [:]
    
    /// Start mDNS discovery for Samsung TVs
    /// - Parameters:
    ///   - timeout: Discovery timeout duration
    ///   - continuation: AsyncStream continuation to emit results
    func discover(timeout: Duration, continuation: AsyncStream<DiscoveryResult>.Continuation) async {
        guard !isScanning else { return }
        
        isScanning = true
        discoveredDevices.removeAll()
        
        #if canImport(OSLog)
        Logger.discovery.info("Starting mDNS discovery for Samsung TVs")
        #endif
        
        // Create browser for Samsung remote service
        let parameters = NWParameters()
        parameters.includePeerToPeer = false
        
        browser = NWBrowser(for: .bonjour(type: "_samsung-remote._tcp", domain: nil), using: parameters)
        
        // Set up state change handler
        browser?.stateUpdateHandler = { [weak self] state in
            Task {
                await self?.handleStateChange(state)
            }
        }
        
        // Set up browse results handler
        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            Task {
                await self?.handleBrowseResults(results, changes: changes, continuation: continuation)
            }
        }
        
        // Start browsing
        let queue = DispatchQueue(label: "com.swiftsamsungframe.mdns")
        browser?.start(queue: queue)
        
        // Wait for timeout
        do {
            try await Task.sleep(for: timeout)
        } catch {
            // Cancelled
        }
        
        // Stop browsing
        await stop()
        
        #if canImport(OSLog)
        Logger.discovery.info("mDNS discovery completed. Found \(self.discoveredDevices.count) devices")
        #endif
    }
    
    /// Stop mDNS discovery
    func stop() async {
        browser?.cancel()
        browser = nil
        isScanning = false
    }
    
    /// Handle browser state changes
    private func handleStateChange(_ state: NWBrowser.State) {
        #if canImport(OSLog)
        switch state {
        case .ready:
            Logger.discovery.debug("mDNS browser ready")
        case .failed(let error):
            Logger.discovery.error("mDNS browser failed: \(error.localizedDescription)")
        case .cancelled:
            Logger.discovery.debug("mDNS browser cancelled")
        default:
            break
        }
        #endif
    }
    
    /// Handle browse results
    private func handleBrowseResults(
        _ results: Set<NWBrowser.Result>,
        changes: Set<NWBrowser.Result.Change>,
        continuation: AsyncStream<DiscoveryResult>.Continuation
    ) {
        for change in changes {
            switch change {
            case .identical:
                break
            case .added(let result), .changed(old: _, new: let result, flags: _):
                Task {
                    await processResult(result, continuation: continuation)
                }
            case .removed(let result):
                #if canImport(OSLog)
                Logger.discovery.debug("Device removed: \(result.endpoint.debugDescription)")
                #endif
                // Remove from discovered devices
                if case .service(let name, _, _, _) = result.endpoint {
                    discoveredDevices.removeValue(forKey: name)
                }
            @unknown default:
                break
            }
        }
    }
    
    /// Process a discovered service
    private func processResult(
        _ result: NWBrowser.Result,
        continuation: AsyncStream<DiscoveryResult>.Continuation
    ) async {
        guard case .service(let name, let type, let domain, _) = result.endpoint else {
            return
        }
        
        #if canImport(OSLog)
        Logger.discovery.debug("Discovered service: \(name).\(type).\(domain)")
        #endif
        
        // Resolve the endpoint to get IP address
        let connection = NWConnection(to: result.endpoint, using: .tcp)
        
        await withCheckedContinuation { (innerContinuation: CheckedContinuation<Void, Never>) in
            var hasResumed = false
            let resumeLock = NSLock()
            
            func resumeOnce() {
                resumeLock.lock()
                defer { resumeLock.unlock() }
                if !hasResumed {
                    hasResumed = true
                    innerContinuation.resume()
                }
            }
            
            connection.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    if let endpoint = connection.currentPath?.remoteEndpoint,
                       case .hostPort(let host, let port) = endpoint {
                        
                        let hostString: String
                        switch host {
                        case .ipv4(let address):
                            hostString = address.debugDescription
                        case .ipv6(let address):
                            hostString = address.debugDescription
                        case .name(let hostname, _):
                            hostString = hostname
                        @unknown default:
                            hostString = host.debugDescription
                        }
                        
                        #if canImport(OSLog)
                        Logger.discovery.info("Resolved device: \(name) at \(hostString):\(port.rawValue)")
                        #endif
                        
                        // Create discovery result
                        let device = TVDevice(
                            id: hostString,
                            host: hostString,
                            port: Int(port.rawValue),
                            name: name,
                            modelName: "Samsung TV", // Will be updated via REST API if needed
                            apiVersion: .v2
                        )
                        
                        let discoveryResult = DiscoveryResult(
                            device: device,
                            discoveryMethod: .mdns
                        )
                        
                        Task { [weak self] in
                            guard let self else { return }
                            await self.handleDiscovery(discoveryResult, continuation: continuation)
                        }
                    }
                    connection.cancel()
                    resumeOnce()
                    
                case .failed, .cancelled:
                    connection.cancel()
                    resumeOnce()
                    
                default:
                    break
                }
            }
            
            let queue = DispatchQueue(label: "com.swiftsamsungframe.mdns.resolve")
            connection.start(queue: queue)
            
            // Set a timeout for resolution
            Task {
                try? await Task.sleep(for: .seconds(5))
                connection.cancel()
                resumeOnce()
            }
        }
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
actor MDNSBrowser {
    func discover(timeout: Duration, continuation: AsyncStream<DiscoveryResult>.Continuation) async {
        #if canImport(OSLog)
        Logger.discovery.warning("mDNS discovery not available on this platform")
        #endif
    }
    
    func stop() async {}
}
#endif
