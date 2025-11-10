import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(os)
import os
#endif

/// REST API client for Samsung TV
public class RESTClient: @unchecked Sendable {
    private let urlSession: URLSession
    private let baseURL: URL
    
    /// Creates a new REST client
    /// - Parameter baseURL: Base URL for REST API
    public init(baseURL: URL) {
        self.baseURL = baseURL
        
        // Configure session to accept self-signed certificates
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 30
        
        self.urlSession = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
    }
    
    /// Performs a GET request
    /// - Parameter path: API path
    /// - Returns: Response data
    public func get(_ path: String) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        #if canImport(os)
        Logger.networking.info("REST GET: \(url.absoluteString)")
        #endif
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TVError.invalidResponse(details: "Not an HTTP response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TVError.invalidResponse(details: "HTTP \(httpResponse.statusCode)")
        }
        
        return data
    }
    
    /// Performs a POST request
    /// - Parameters:
    ///   - path: API path
    ///   - body: Request body data
    /// - Returns: Response data
    public func post(_ path: String, body: Data?) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        #if canImport(os)
        Logger.networking.info("REST POST: \(url.absoluteString)")
        #endif
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TVError.invalidResponse(details: "Not an HTTP response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TVError.invalidResponse(details: "HTTP \(httpResponse.statusCode)")
        }
        
        return data
    }
    
    /// Performs a DELETE request
    /// - Parameter path: API path
    /// - Returns: Response data
    public func delete(_ path: String) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        #if canImport(os)
        Logger.networking.info("REST DELETE: \(url.absoluteString)")
        #endif
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TVError.invalidResponse(details: "Not an HTTP response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TVError.invalidResponse(details: "HTTP \(httpResponse.statusCode)")
        }
        
        return data
    }
    
    /// Uploads multipart form data
    /// - Parameters:
    ///   - path: API path
    ///   - fields: Form fields
    ///   - files: Files to upload (name, data, filename, mimeType)
    /// - Returns: Response data
    public func uploadMultipart(
        _ path: String,
        fields: [String: String],
        files: [(name: String, data: Data, filename: String, mimeType: String)]
    ) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add fields
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add files
        for file in files {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(file.mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(file.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        #if canImport(os)
        Logger.networking.info("REST multipart upload: \(url.absoluteString)")
        #endif
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TVError.invalidResponse(details: "Not an HTTP response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TVError.invalidResponse(details: "HTTP \(httpResponse.statusCode)")
        }
        
        return data
    }
}
