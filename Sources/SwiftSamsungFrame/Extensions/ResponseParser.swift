// ResponseParser - Utilities for parsing WebSocket responses
// Handles JSON responses with optional binary data tail

import Foundation

/// Errors that can occur during response parsing
public enum ResponseParseError: Error, Sendable {
    case jsonStartNotFound
    case jsonEndNotFound
    case invalidUTF8
    case invalidJSON
}

/// Result of parsing a WebSocket response that may contain JSON + binary data
public struct ParsedResponse: Sendable {
    /// The raw JSON data
    public let jsonData: Data
    
    /// Optional binary data that followed the JSON (e.g., thumbnail image)
    public let binaryData: Data?
    
    /// Length of the binary data
    public var binaryLength: Int {
        binaryData?.count ?? 0
    }
    
    public init(jsonData: Data, binaryData: Data? = nil) {
        self.jsonData = jsonData
        self.binaryData = binaryData
    }
}

/// Utilities for parsing Samsung TV WebSocket responses
public enum ResponseParser {
    /// Split WebSocket bytes payload into (JSON bytes, tail bytes)
    ///
    /// Some Samsung TV responses (particularly Art Mode responses) contain JSON followed
    /// by binary data. This function separates them by parsing the JSON structure.
    ///
    /// - Parameter data: Raw bytes from WebSocket message
    /// - Returns: Tuple of (JSON data, remaining binary data)
    /// - Throws: ResponseParseError if JSON structure cannot be found
    public static func splitJSONAndTail(_ data: Data) throws -> (jsonData: Data, tailData: Data) {
        // Find start of JSON object
        guard let start = data.firstIndex(of: UInt8(ascii: "{")) else {
            throw ResponseParseError.jsonStartNotFound
        }
        
        // Parse through JSON to find matching closing brace
        var depth = 0
        var end: Int?
        
        for i in start..<data.count {
            let byte = data[i]
            if byte == 0x7B { // '{'
                depth += 1
            } else if byte == 0x7D { // '}'
                depth -= 1
                if depth == 0 {
                    end = i + 1
                    break
                }
            }
        }
        
        guard let end = end else {
            throw ResponseParseError.jsonEndNotFound
        }
        
        let jsonData = data[start..<end]
        var tailData = data[end...]
        
        // Skip leading newline in tail if present
        if tailData.first == UInt8(ascii: "\n") {
            tailData = tailData.dropFirst()
        }
        
        return (Data(jsonData), Data(tailData))
    }
    
    /// Process a WebSocket API response that may contain JSON or JSON + binary data
    ///
    /// This handles three cases:
    /// 1. String responses (pure JSON)
    /// 2. Data responses that are pure JSON
    /// 3. Data responses that are JSON + binary tail (Art Mode thumbnails, etc.)
    ///
    /// - Parameter response: Raw response data from WebSocket
    /// - Returns: ParsedResponse containing JSON data and optional binary data
    /// - Throws: ResponseParseError if parsing fails
    public static func processAPIResponse(_ response: Data) throws -> ParsedResponse {
        // Try to decode as pure UTF-8 JSON first
        if String(data: response, encoding: .utf8) != nil {
            do {
                // Validate it's proper JSON
                _ = try JSONSerialization.jsonObject(with: response)
                return ParsedResponse(jsonData: response, binaryData: nil)
            } catch {
                // Fall through to try split parsing
            }
        }
        
        // Response might be JSON + binary tail
        do {
            let (jsonData, tailData) = try splitJSONAndTail(response)
            
            // Validate the JSON portion
            _ = try JSONSerialization.jsonObject(with: jsonData)
            
            let binaryData = tailData.isEmpty ? nil : tailData
            return ParsedResponse(jsonData: jsonData, binaryData: binaryData)
            
        } catch {
            throw ResponseParseError.invalidJSON
        }
    }
    
    /// Generate a random connection ID for D2D socket handshake
    ///
    /// Returns a random integer in the range [0, 4GB) used for identifying
    /// the connection during D2D (device-to-device) socket communications.
    ///
    /// - Returns: Random connection identifier
    public static func generateConnectionID() -> UInt32 {
        // 4GB = 4 * 1024 * 1024 * 1024 = 4294967296, but UInt32.max = 4294967295
        // So we use UInt32.max as the upper bound
        return UInt32.random(in: 0...UInt32.max)
    }
}
