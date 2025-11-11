// RESTClient - HTTP REST API client for Samsung TV
// Handles REST API requests for device info and art management

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// HTTP REST client for Samsung TV API
public final class RESTClient: @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    
    /// Initialize REST client
    /// - Parameter baseURL: Base URL for REST API (http://host:8001)
    public init(baseURL: URL) {
        self.baseURL = baseURL
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 60
        
        self.session = URLSession(configuration: configuration)
    }
    
    /// Get device information
    /// - Returns: Device info JSON data
    /// - Throws: TVError if request fails
    public func getDeviceInfo() async throws -> Data {
        let url = baseURL.appendingPathComponent("/api/v2/")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TVError.invalidResponse(details: "Invalid response type")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TVError.commandFailed(
                code: httpResponse.statusCode,
                message: "HTTP \(httpResponse.statusCode)"
            )
        }
        
        return data
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
        let url = baseURL.appendingPathComponent("/api/v2/art/ms/content/upload")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
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
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TVError.invalidResponse(details: "Invalid response type")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TVError.uploadFailed(reason: "HTTP \(httpResponse.statusCode)")
        }
        
        return data
    }
    
    /// Get art thumbnail
    /// - Parameter artID: Art piece identifier
    /// - Returns: Thumbnail image data
    /// - Throws: TVError if request fails
    public func getArtThumbnail(artID: String) async throws -> Data {
        let url = baseURL.appendingPathComponent("/api/v2/art/ms/content/\(artID)/thumbnail")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TVError.invalidResponse(details: "Invalid response type")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TVError.commandFailed(
                code: httpResponse.statusCode,
                message: "Failed to fetch thumbnail"
            )
        }
        
        return data
    }
    
    /// Delete art piece
    /// - Parameter artID: Art piece identifier
    /// - Throws: TVError if request fails
    public func deleteArt(artID: String) async throws {
        let url = baseURL.appendingPathComponent("/api/v2/art/ms/content/\(artID)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TVError.invalidResponse(details: "Invalid response type")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TVError.commandFailed(
                code: httpResponse.statusCode,
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
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TVError.invalidResponse(details: "Invalid response type")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TVError.commandFailed(
                code: httpResponse.statusCode,
                message: "Failed to fetch icon"
            )
        }
        
        return data
    }
    
    /// Get app status
    /// - Parameter appID: App identifier
    /// - Returns: App status data
    /// - Throws: TVError if request fails
    public func getAppStatus(appID: String) async throws -> Data {
        let url = baseURL.appendingPathComponent("/api/v2/applications/\(appID)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TVError.invalidResponse(details: "Invalid response type")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TVError.commandFailed(
                code: httpResponse.statusCode,
                message: "Failed to get app status"
            )
        }
        
        return data
    }
    
    /// Launch app via REST API
    /// - Parameter appID: App identifier
    /// - Throws: TVError if request fails
    public func launchApp(appID: String) async throws {
        let url = baseURL.appendingPathComponent("/api/v2/applications/\(appID)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TVError.invalidResponse(details: "Invalid response type")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TVError.commandFailed(
                code: httpResponse.statusCode,
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
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TVError.invalidResponse(details: "Invalid response type")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TVError.commandFailed(
                code: httpResponse.statusCode,
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
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TVError.invalidResponse(details: "Invalid response type")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TVError.commandFailed(
                code: httpResponse.statusCode,
                message: "Failed to install app"
            )
        }
    }
}
