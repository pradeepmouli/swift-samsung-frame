import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// HTTP REST client for Samsung TV API
public final class RESTClient: @unchecked Sendable {
    public struct RequestLog: Sendable {
        public let method: String
        public let url: URL
        public let headers: [String: String]
        public let body: Data?
    }

    public struct ResponseLog: Sendable {
        public let statusCode: Int
        public let headers: [String: String]
        public let body: Data?
        public let duration: TimeInterval
    }

    public struct FailureLog: Sendable {
        public let message: String
        public let detail: String?
    }

    public enum LogEvent: Sendable {
        case request(id: UUID, payload: RequestLog)
        case response(id: UUID, payload: ResponseLog)
        case failure(id: UUID, payload: FailureLog)
    }

    public typealias LogObserver = @Sendable (LogEvent) -> Void

    private let baseURL: URL
    private let session: URLSession
    private let observerLock = NSLock()
    private var observers: [UUID: LogObserver] = [:]
    
    /// Base endpoint for REST interactions
    public var serviceBaseURL: URL { baseURL }
    
    /// Initialize REST client
    /// - Parameter baseURL: Base URL for REST API (http://host:8001)
    public init(baseURL: URL) {
        self.baseURL = baseURL
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 60
        
        self.session = URLSession(configuration: configuration)
    }

    /// Add an observer to receive REST request/response diagnostics
    @discardableResult
    public func addObserver(_ observer: @escaping LogObserver) -> UUID {
        let id = UUID()
        observerLock.lock()
        observers[id] = observer
        observerLock.unlock()
        return id
    }

    /// Remove a previously registered observer
    public func removeObserver(_ id: UUID) {
        observerLock.lock()
        observers.removeValue(forKey: id)
        observerLock.unlock()
    }
    
    /// Get device information
    /// - Returns: Device info JSON data
    /// - Throws: TVError if request fails
    public func getDeviceInfo() async throws -> Data {
        let url = baseURL.appendingPathComponent("/api/v2/")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        return try await perform(request) { response, _ in
            TVError.commandFailed(
                code: response.statusCode,
                message: "HTTP \(response.statusCode)"
            )
        }
    }
    
    /// Upload image for art mode
    /// - Parameters:
    ///   - imageData: Image data to upload
    ///   - fileName: Image file name
    ///   - matte: Optional matte style
    /// - Returns: Upload response data
    /// - Throws: TVError if upload fails
    public func uploadImage(
        _ imageData: Data,
        fileName: String,
        matte: MatteStyle? = nil
    ) async throws -> Data {
        #if os(watchOS)
        // Art upload is intentionally disabled on watchOS due to memory and capability constraints
        throw TVError.uploadFailed(reason: "Art upload is not supported on watchOS")
        #else
        let url = baseURL.appendingPathComponent("/api/v2/art/ms/content/upload")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()

        // Choose MIME type based on file name extension, default to JPEG
        let lowercased = fileName.lowercased()
        let mimeType: String = lowercased.hasSuffix(".png") ? "image/png" : "image/jpeg"
        
        // Add image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add matte if specified
        if let matte {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"matte\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(matte.rawValue)\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        return try await perform(request) { response, _ in
            TVError.uploadFailed(reason: "HTTP \(response.statusCode)")
        }
        #endif
    }
    
    /// Get art thumbnail
    /// - Parameter artID: Art piece identifier
    /// - Returns: Thumbnail image data
    /// - Throws: TVError if request fails
    public func getArtThumbnail(artID: String) async throws -> Data {
        let url = baseURL.appendingPathComponent("/api/v2/art/ms/content/\(artID)/thumbnail")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        return try await perform(request) { response, _ in
            TVError.commandFailed(
                code: response.statusCode,
                message: "Failed to fetch thumbnail"
            )
        }
    }
    
    /// Delete art piece
    /// - Parameter artID: Art piece identifier
    /// - Throws: TVError if request fails
    public func deleteArt(artID: String) async throws {
        let url = baseURL.appendingPathComponent("/api/v2/art/ms/content/\(artID)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        _ = try await perform(request) { response, _ in
            TVError.commandFailed(
                code: response.statusCode,
                message: "Failed to delete art"
            )
        }
    }
    
    /// Get app icon
    /// - Parameter appID: App identifier
    /// - Returns: Icon image data
    /// - Throws: TVError if request fails
    public func getAppIcon(appID: String) async throws -> Data {
        let url = baseURL.appendingPathComponent("/api/v2/applications/\(appID)/icon")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        return try await perform(request) { response, _ in
            TVError.commandFailed(
                code: response.statusCode,
                message: "Failed to fetch icon"
            )
        }
    }
    
    /// Get app status
    /// - Parameter appID: App identifier
    /// - Returns: App status data
    /// - Throws: TVError if request fails
    public func getAppStatus(appID: String) async throws -> Data {
        let url = baseURL.appendingPathComponent("/api/v2/applications/\(appID)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        return try await perform(request) { response, _ in
            TVError.commandFailed(
                code: response.statusCode,
                message: "Failed to get app status"
            )
        }
    }
    
    /// Launch app via REST API
    /// - Parameter appID: App identifier
    /// - Throws: TVError if request fails
    public func launchApp(appID: String) async throws {
        let url = baseURL.appendingPathComponent("/api/v2/applications/\(appID)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        _ = try await perform(request) { response, _ in
            TVError.commandFailed(
                code: response.statusCode,
                message: "Failed to launch app"
            )
        }
    }
    
    /// Close app via REST API
    /// - Parameter appID: App identifier
    /// - Throws: TVError if request fails
    public func closeApp(appID: String) async throws {
        let url = baseURL.appendingPathComponent("/api/v2/applications/\(appID)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        _ = try await perform(request) { response, _ in
            TVError.commandFailed(
                code: response.statusCode,
                message: "Failed to close app"
            )
        }
    }
    
    /// Install app via REST API
    /// - Parameter appID: App identifier
    /// - Throws: TVError if request fails
    public func installApp(appID: String) async throws {
        let url = baseURL.appendingPathComponent("/api/v2/applications/\(appID)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        
        _ = try await perform(request) { response, _ in
            TVError.commandFailed(
                code: response.statusCode,
                message: "Failed to install app"
            )
        }
    }

    private func perform(
        _ request: URLRequest,
        acceptableStatus: Range<Int> = 200..<300,
        errorBuilder: (HTTPURLResponse, Data) -> TVError
    ) async throws -> Data {
        var loggedFailure = false
        let requestID = UUID()

        let requestLog = RequestLog(
            method: request.httpMethod ?? "GET",
            url: request.url ?? baseURL,
            headers: request.allHTTPHeaderFields ?? [:],
            body: request.httpBody
        )
        notifyObservers(.request(id: requestID, payload: requestLog))

        let start = Date()
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                loggedFailure = true
                notifyObservers(.failure(
                    id: requestID,
                    payload: FailureLog(
                        message: "Invalid response type",
                        detail: "\(type(of: response))"
                    )
                ))
                throw TVError.invalidResponse(details: "Invalid response type")
            }

            let duration = Date().timeIntervalSince(start)
            let responseLog = ResponseLog(
                statusCode: httpResponse.statusCode,
                headers: headersDictionary(from: httpResponse),
                body: data,
                duration: duration
            )
            notifyObservers(.response(id: requestID, payload: responseLog))

            guard acceptableStatus.contains(httpResponse.statusCode) else {
                loggedFailure = true
                let error = errorBuilder(httpResponse, data)
                notifyObservers(.failure(
                    id: requestID,
                    payload: FailureLog(message: error.localizedDescription, detail: nil)
                ))
                throw error
            }

            return data
        } catch {
            if !loggedFailure {
                notifyObservers(.failure(
                    id: requestID,
                    payload: FailureLog(message: error.localizedDescription, detail: nil)
                ))
            }
            throw error
        }
    }

    private func notifyObservers(_ event: LogEvent) {
        let snapshot: [LogObserver]
        observerLock.lock()
        snapshot = Array(observers.values)
        observerLock.unlock()
        for observer in snapshot {
            observer(event)
        }
    }

    private func headersDictionary(from response: HTTPURLResponse) -> [String: String] {
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            guard let headerField = key as? String else { continue }
            if let stringValue = value as? String {
                headers[headerField] = stringValue
            } else {
                headers[headerField] = "\(value)"
            }
        }
        return headers
    }
}
