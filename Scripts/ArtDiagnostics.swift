import Foundation
import SwiftSamsungFrame

@main
struct ArtDiagnosticsCLI {
    static func main() async {
        let options = parseOptions()

        print("=== SwiftSamsungFrame Diagnostics ===")
        print("Target host: \(options.host)")
        print("WebSocket port: \(options.port)")
        if let imagePath = options.imagePath {
            print("Image path: \(imagePath)")
        }
        print("")

        if options.skipDiscovery {
            print("--- Discovery skipped (--skip-discovery) ---")
        } else {
            await runDiscovery(for: options.host)
            print("")
        }
        await runArtDiagnostics(host: options.host, imagePath: options.imagePath, options: options)
    }

    private struct Options {
        var host: String = "192.168.1.42"
        var imagePath: String?
        var skipDiscovery = false
        var dumpWebSocket = false
        var dumpREST = false
        var monitorSeconds: TimeInterval = 0
        var port: Int = 8001
    }

    private static func parseOptions() -> Options {
        var iterator = CommandLine.arguments.dropFirst().makeIterator()
        var options = Options()

        while let arg = iterator.next() {
            switch arg {
            case "--host":
                if let value = iterator.next(), !value.isEmpty {
                    options.host = value
                }
            case "--port":
                if let value = iterator.next(), let number = Int(value), number > 0 {
                    options.port = number
                } else {
                    stderr("Invalid value for --port. Provide a positive integer.\n")
                    printUsageAndExit(exitCode: 1)
                }
            case "--image":
                if let value = iterator.next(), !value.isEmpty {
                    options.imagePath = value
                }
            case "--dump-websocket":
                options.dumpWebSocket = true
            case "--dump-rest":
                options.dumpREST = true
            case "--monitor-seconds":
                if let value = iterator.next(), let seconds = TimeInterval(value), seconds >= 0 {
                    options.monitorSeconds = seconds
                } else {
                    stderr("Invalid value for --monitor-seconds. Provide a non-negative number.\n")
                    printUsageAndExit(exitCode: 1)
                }
            case "--skip-discovery":
                options.skipDiscovery = true
            case "--help", "-h":
                printUsageAndExit()
            default:
                stderr("Unknown argument: \(arg)\n")
                printUsageAndExit(exitCode: 1)
            }
        }

        return options
    }

    private static func printUsageAndExit(exitCode: Int32 = 0) -> Never {
        let usage = """
                Usage: swift ArtDiagnostics.swift [--host <ip>] [--image <path>]

                    --host <ip>	Override TV IP (default 192.168.1.42)
                        --port <n>	Override WebSocket port (default 8001; use 8002 for TLS)
                    --image <path>	Upload image at path for end-to-end verification
                    --dump-websocket\tDump every raw WebSocket message received during diagnostics
                        --dump-rest	Dump REST requests and responses made during diagnostics
                    --monitor-seconds <n>\tKeep the monitor attached for N seconds after diagnostics (default 0)
                    --skip-discovery	Skip mDNS/SSDP discovery and go straight to Art diagnostics
                    --help, -h	Show this help message
        """
        print(usage)
        exit(exitCode)
    }

    private static func stderr(_ message: String) {
        FileHandle.standardError.write(Data(message.utf8))
    }

    private static func runDiscovery(for expectedHost: String) async {
        print("--- Discovery (mDNS + SSDP fallback) ---")
        let discovery = DiscoveryService()
        var discovered: [DiscoveryResult] = []

        #if canImport(Network)
        let timeout = Duration.seconds(8)
        let start = Date()
        for await result in discovery.discover(timeout: timeout) {
            discovered.append(result)
            print("• Found \(result.device.name) @ \(result.device.host) via \(result.discoveryMethod.rawValue.uppercased())")
        }
        discovery.cancel()
        let elapsed = Date().timeIntervalSince(start)
        print("Discovery complete in \(String(format: "%.2f", elapsed))s; \(discovered.count) device(s) total")
        if let match = discovered.first(where: { $0.device.host == expectedHost }) {
            print("✅ Expected host \(expectedHost) discovered as \(match.device.name)")
        } else {
            print("⚠️ Expected host \(expectedHost) was NOT discovered; ensure the TV is on the same subnet and Art Mode is enabled")
        }
        #else
        print("Discovery unavailable on this platform (Network framework not present). Skipping.")
        #endif
    }

    private static func runArtDiagnostics(host: String, imagePath: String?, options: Options) async {
        print("--- Art Mode Diagnostics ---")
        let client = TVClient()
        var connected = false
        var monitorHandle: MonitorHandle?
    var restObserverID: UUID?
        do {
            print("Connecting to \(host):\(options.port)...")
            let session = try await client.connect(to: host, port: options.port, channel: .artApp)
            connected = true
            print("Connected. Querying Art Mode support...")

            if options.dumpWebSocket {
                monitorHandle = await attachWebSocketMonitor(for: session)
            }

            if options.dumpREST {
                restObserverID = await attachRESTMonitor(to: client)
            }

            let supported = try await client.art.isSupported()
            print("Art Mode supported: \(supported)")
            guard supported else { return }

            do {
                print("Checking current Art Mode state...")
                let active = try await client.art.isArtModeActive()
                print("Art Mode active: \(active)")
            } catch {
                print("⚠️ Unable to determine Art Mode status: \(error)")
            }

            print("Fetching available art list...")
            let artPieces = try await client.art.listAvailable()
            print("Available art count: \(artPieces.count)")
            for piece in artPieces.prefix(5) {
                print("  - \(piece.id): \(piece.title)")
            }

            if let current = try? await client.art.current() {
                print("Current art: \(current.id) — \(current.title)")
            }

            do {
                print("Fetching available filters...")
                let filters = try await client.art.availableFilters()
                if filters.isEmpty {
                    print("Filters: (none reported)")
                } else {
                    let list = filters.map { $0.rawValue }.joined(separator: ", ")
                    print("Filters: \(list)")
                }
            } catch {
                print("⚠️ Unable to fetch filters: \(error)")
            }

            if let path = imagePath {
                print("Preparing upload for \(path)...")
                await performUpload(at: path, with: client)
            }

            if options.monitorSeconds > 0 {
                print("Monitoring inbound WebSocket traffic for \(Int(options.monitorSeconds)) second(s)...")
                try? await Task.sleep(for: .seconds(options.monitorSeconds))
            }

            if let handle = monitorHandle {
                await detachWebSocketMonitor(handle)
                monitorHandle = nil
            }

            if let restID = restObserverID {
                await client.removeRESTObserver(restID)
                restObserverID = nil
            }

            await client.disconnect()
            connected = false
            print("Disconnected from TV.")
        } catch {
            print("❌ Failed to connect or run diagnostics: \(error)")
            if connected {
                if let handle = monitorHandle {
                    await detachWebSocketMonitor(handle)
                    monitorHandle = nil
                }
                if let restID = restObserverID {
                    await client.removeRESTObserver(restID)
                    restObserverID = nil
                }
                await client.disconnect()
            }
        }
    }

    private struct MonitorHandle {
        let socket: WebSocketClient
        let handlerID: UUID
    }

    private static func attachWebSocketMonitor(for session: ConnectionSession) async -> MonitorHandle? {
        guard let webSocket = await session.webSocket() else {
            print("⚠️ Unable to attach WebSocket monitor: no active socket available")
            return nil
        }

        print("Attaching WebSocket monitor (raw message dump enabled)...")
        let handlerID = await webSocket.addMessageHandler { data in
            let timestamp = isoTimestamp()
            let rendered = renderWebSocketMessage(data)
            print("[\(timestamp)] ←\n\(rendered)\n")
        }
        return MonitorHandle(socket: webSocket, handlerID: handlerID)
    }

    private static func detachWebSocketMonitor(_ handle: MonitorHandle) async {
        await handle.socket.removeMessageHandler(handle.handlerID)
        print("WebSocket monitor detached.")
    }

    private static func attachRESTMonitor(to client: TVClient) async -> UUID? {
        guard let id = await client.addRESTObserver({ @Sendable event in
            let timestamp = isoTimestamp()
            switch event {
            case .request(let requestID, let payload):
                print("[\(timestamp)] REST REQUEST #\(shortID(requestID)) \(payload.method) \(payload.url.absoluteString)")
                if !payload.headers.isEmpty {
                    print(renderHeaders(payload.headers))
                }
                if let body = payload.body, !body.isEmpty {
                    print(renderDataBody(body))
                }
                print("")
            case .response(let requestID, let payload):
                let durationMS = String(format: "%.2f", payload.duration * 1000)
                print("[\(timestamp)] REST RESPONSE #\(shortID(requestID)) status=\(payload.statusCode) duration=\(durationMS)ms")
                if !payload.headers.isEmpty {
                    print(renderHeaders(payload.headers))
                }
                if let body = payload.body, !body.isEmpty {
                    print(renderDataBody(body))
                }
                print("")
            case .failure(let requestID, let payload):
                print("[\(timestamp)] REST FAILURE #\(shortID(requestID)): \(payload.message)")
                if let detail = payload.detail {
                    print(detail)
                }
                print("")
            }
        }) else {
            print("⚠️ Unable to attach REST monitor: REST client not available")
            return nil
        }
        print("REST monitor attached.")
        return id
    }

    private static func renderWebSocketMessage(_ data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data),
           JSONSerialization.isValidJSONObject(object),
           let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
           let string = String(data: pretty, encoding: .utf8) {
            return string
        }

        if let string = String(data: data, encoding: .utf8), !string.isEmpty {
            return string
        }

        return data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    private static func isoTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    private static func renderHeaders(_ headers: [String: String]) -> String {
        headers
            .sorted { $0.key.lowercased() < $1.key.lowercased() }
            .map { "  \($0): \($1)" }
            .joined(separator: "\n")
    }

    private static func renderDataBody(_ data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data),
           JSONSerialization.isValidJSONObject(object),
           let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
           let string = String(data: pretty, encoding: .utf8) {
            return string
        }

        if let string = String(data: data, encoding: .utf8), !string.isEmpty {
            return string
        }

        return data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    private static func shortID(_ id: UUID) -> String {
        id.uuidString.prefix(8).uppercased()
    }

    private static func performUpload(at path: String, with client: TVClient) async {
        print("")
        print("--- Upload Test ---")
        let url = URL(fileURLWithPath: path)
        do {
            let data = try Data(contentsOf: url)
            let type: ImageType = url.pathExtension.lowercased() == "png" ? .png : .jpeg
            let contentID = try await client.art.upload(data, type: type, matte: nil)
            print("Uploaded content ID: \(contentID)")

            let updated = try await client.art.listAvailable()
            if updated.contains(where: { $0.id == contentID }) {
                print("✅ Upload verified in library")
            } else {
                print("⚠️ Upload ID not found in refreshed list; check TV logs")
            }

            do {
                try await client.art.select(contentID, show: true)
                print("Selected uploaded art and requested display")
            } catch {
                print("⚠️ Failed to select uploaded art: \(error)")
            }
        } catch {
            print("❌ Upload test failed: \(error)")
        }
    }
}
