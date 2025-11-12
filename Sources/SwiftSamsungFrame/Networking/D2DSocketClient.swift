// D2DSocketClient - Device-to-Device socket client for art transfers
// Handles direct TCP socket connections for image upload/download

import Foundation

#if canImport(Network)
import Network

#if canImport(OSLog)
import OSLog
#endif

/// Client for device-to-device socket transfers used by Art Mode
/// Uses Network framework for TCP socket connections on Apple platforms
public actor D2DSocketClient {
    private var connection: NWConnection?
    private let timeout: Duration = .seconds(30)
    
    /// Public initializer for D2DSocketClient
    public init() {}
    
    /// Helper to generate random connection ID
    public static func generateConnectionID() -> Int {
        Int.random(in: 0..<min(4 * 1024 * 1024 * 1024, Int.max))
    }
    
    /// Establish a TCP connection to the specified host and port
    /// - Parameters:
    ///   - host: Host IP address
    ///   - port: Port number
    ///   - queueLabel: Label for the dispatch queue
    /// - Returns: Connected NWConnection
    /// - Throws: TVError if connection fails
    private func establishConnection(
        to host: String,
        port: Int,
        queueLabel: String
    ) async throws -> NWConnection {
        // Create connection
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port))
        )
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        let conn = NWConnection(to: endpoint, using: parameters)
        self.connection = conn
        
        // Start connection
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            final class ResumeState: @unchecked Sendable {
                private var resumed = false
                private let lock = NSLock()
                var timeoutTask: Task<Void, Never>?
                func resumeOnce(_ result: Result<Void, any Error>, continuation: CheckedContinuation<Void, any Error>) {
                    lock.lock(); defer { lock.unlock() }
                    guard !resumed else { return }
                    resumed = true
                    timeoutTask?.cancel()
                    continuation.resume(with: result)
                }
            }
            let state = ResumeState()
            
            conn.stateUpdateHandler = { st in
                switch st {
                case .ready:
                    #if canImport(OSLog)
                    Logger.networking.debug("D2D: Connection ready")
                    #endif
                    state.resumeOnce(.success(()), continuation: continuation)
                    
                case .failed(let error):
                    #if canImport(OSLog)
                    Logger.networking.error("D2D: Connection failed: \(error.localizedDescription)")
                    #endif
                    state.resumeOnce(.failure(TVError.connectionFailed(reason: error.localizedDescription)), continuation: continuation)
                    
                case .cancelled:
                    #if canImport(OSLog)
                    Logger.networking.debug("D2D: Connection cancelled")
                    #endif
                    state.resumeOnce(.failure(TVError.connectionFailed(reason: "Connection cancelled")), continuation: continuation)
                    
                default:
                    break
                }
            }
            
            let queue = DispatchQueue(label: queueLabel)
            conn.start(queue: queue)
            
            // Set timeout
            state.timeoutTask = Task {
                try? await Task.sleep(for: self.timeout)
                state.resumeOnce(.failure(TVError.timeout(operation: "D2DConnect")), continuation: continuation)
            }
        }
        
        return conn
    }
    
    /// Send data over D2D socket connection
    /// - Parameters:
    ///   - host: Host IP address
    ///   - port: Port number
    ///   - data: Data to send
    /// - Throws: TVError if transfer fails
    public func send(to host: String, port: Int, data: Data) async throws {
        #if canImport(OSLog)
        Logger.networking.info("D2D: Sending \(data.count) bytes to \(host):\(port)")
        #endif
        
        // Establish connection
        let conn = try await establishConnection(
            to: host,
            port: port,
            queueLabel: "com.swiftsamsungframe.d2d.send"
        )
        
        // Send data
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { error in
                if let error {
                    #if canImport(OSLog)
                    Logger.networking.error("D2D: Send failed: \(error.localizedDescription)")
                    #endif
                    continuation.resume(throwing: TVError.connectionFailed(reason: error.localizedDescription))
                } else {
                    #if canImport(OSLog)
                    Logger.networking.info("D2D: Successfully sent \(data.count) bytes")
                    #endif
                    continuation.resume()
                }
            })
        }
        
        // Close connection
        conn.cancel()
        self.connection = nil
    }
    
    /// Receive data from D2D socket connection
    /// - Parameters:
    ///   - host: Host IP address
    ///   - port: Port number
    ///   - expectedLength: Expected data length in bytes
    /// - Returns: Received data
    /// - Throws: TVError if transfer fails
    public func receive(from host: String, port: Int, expectedLength: Int) async throws -> Data {
        #if canImport(OSLog)
        Logger.networking.info("D2D: Receiving up to \(expectedLength) bytes from \(host):\(port)")
        #endif
        
        // Establish connection
        let conn = try await establishConnection(
            to: host,
            port: port,
            queueLabel: "com.swiftsamsungframe.d2d.receive"
        )
        
        // Receive data
    let receivedData = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, any Error>) in
            conn.receive(minimumIncompleteLength: 1, maximumLength: expectedLength) { content, _, isComplete, error in
                if let error {
                    #if canImport(OSLog)
                    Logger.networking.error("D2D: Receive failed: \(error.localizedDescription)")
                    #endif
                    continuation.resume(throwing: TVError.connectionFailed(reason: error.localizedDescription))
                } else if let content {
                    #if canImport(OSLog)
                    Logger.networking.info("D2D: Received \(content.count) bytes")
                    #endif
                    continuation.resume(returning: content)
                } else {
                    continuation.resume(throwing: TVError.connectionFailed(reason: "No data received"))
                }
            }
        }
        
        // Close connection
        conn.cancel()
        self.connection = nil
        
        return receivedData
    }
    
    /// Transfer data using TCP connection
    /// - Parameters:
    ///   - host: Host IP address
    ///   - port: Port number
    ///   - operation: Operation to perform (send or receive)
    ///   - data: Data to send (for send operation, ignored for receive)
    /// - Returns: Received data (for receive operation), nil for send
    /// - Throws: TVError if transfer fails
    public func transfer(
        to host: String,
        port: Int,
        operation: TransferOperation,
        data: Data? = nil
    ) async throws -> Data? {
        switch operation {
        case .send(let dataToSend):
            try await send(to: host, port: port, data: dataToSend)
            return nil
            
        case .receive(let expectedLength):
            return try await receive(from: host, port: port, expectedLength: expectedLength)
        }
    }
    
    /// Cancel any active connection
    public func cancel() {
        connection?.cancel()
        connection = nil
    }
    
    public enum TransferOperation {
        case send(Data)
        case receive(expectedLength: Int)
    }
}

#else
// Stub implementation for platforms without Network framework
public actor D2DSocketClient {
    public init() {}
    public static func generateConnectionID() -> Int {
        Int.random(in: 0..<min(4 * 1024 * 1024 * 1024, Int.max))
    }
    
    public func send(to host: String, port: Int, data: Data) async throws {
        throw TVError.commandFailed(
            code: 501,
            message: "D2D socket transfer not available on this platform"
        )
    }
    
    public func receive(from host: String, port: Int, expectedLength: Int) async throws -> Data {
        throw TVError.commandFailed(
            code: 501,
            message: "D2D socket transfer not available on this platform"
        )
    }
    
    public func transfer(
        to host: String,
        port: Int,
        operation: TransferOperation,
        data: Data? = nil
    ) async throws -> Data? {
        throw TVError.commandFailed(
            code: 501,
            message: "D2D socket transfer not available on this platform"
        )
    }
    
    public func cancel() {}
    
    public enum TransferOperation {
        case send(Data)
        case receive(expectedLength: Int)
    }
}
#endif

