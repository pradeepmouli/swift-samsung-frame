// Tests for ResponseParser utilities
// Validates JSON/binary response parsing functionality

import Testing
import Foundation
@testable import SwiftSamsungFrame

@Test("ResponseParser generates random connection IDs")
func testGenerateConnectionID() async throws {
    // Note: Connection ID generation is provided by D2DSocketClient.generateConnectionID()
    // This test verifies the basic pattern works
    let id1 = D2DSocketClient.generateConnectionID()
    let id2 = D2DSocketClient.generateConnectionID()
    
    // Verify IDs are (very likely) different
    #expect(id1 != id2)
}

@Test("ResponseParser splits JSON and binary tail correctly")
func testSplitJSONAndTail() async throws {
    // Test case 1: JSON with binary tail
    let jsonString = #"{"event":"test","data":"value"}"#
    let binaryData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG magic bytes
    var combined = jsonString.data(using: .utf8)!
    combined.append(binaryData)
    
    let (jsonData, tailData) = try ResponseParser.splitJSONAndTail(combined)
    
    #expect(jsonData.count > 0)
    #expect(tailData.count == 4)
    #expect(tailData == binaryData)
    
    // Verify JSON is valid
    let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
    #expect(json?["event"] as? String == "test")
}

@Test("ResponseParser handles JSON with newline before binary")
func testSplitJSONWithNewline() async throws {
    let jsonString = #"{"status":"ok"}"#
    let binaryData = Data([0x01, 0x02, 0x03])
    var combined = jsonString.data(using: .utf8)!
    combined.append(Data([0x0A])) // Add newline
    combined.append(binaryData)
    
    let (jsonData, tailData) = try ResponseParser.splitJSONAndTail(combined)
    
    #expect(jsonData.count > 0)
    #expect(tailData.count == 3) // Newline should be stripped
    #expect(tailData == binaryData)
}

@Test("ResponseParser handles nested JSON objects")
func testSplitNestedJSON() async throws {
    let jsonString = #"{"outer":{"inner":"value"},"array":[1,2,3]}"#
    let binaryData = Data([0xAB, 0xCD])
    var combined = jsonString.data(using: .utf8)!
    combined.append(binaryData)
    
    let (jsonData, tailData) = try ResponseParser.splitJSONAndTail(combined)
    
    #expect(jsonData.count > 0)
    #expect(tailData.count == 2)
    
    // Verify nested structure is preserved
    let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
    #expect(json?["outer"] as? [String: Any] != nil)
}

@Test("ResponseParser throws on invalid JSON start")
func testSplitJSONMissingStart() async throws {
    let invalidData = Data([0x01, 0x02, 0x03]) // No JSON
    
    #expect(throws: ResponseParseError.self) {
        _ = try ResponseParser.splitJSONAndTail(invalidData)
    }
}

@Test("ResponseParser throws on unclosed JSON")
func testSplitJSONMissingEnd() async throws {
    let unclosedJSON = #"{"event":"test""#.data(using: .utf8)!
    
    #expect(throws: ResponseParseError.self) {
        _ = try ResponseParser.splitJSONAndTail(unclosedJSON)
    }
}

@Test("ResponseParser processes pure JSON response")
func testProcessPureJSON() async throws {
    let jsonString = #"{"method":"response","status":"ok"}"#
    let jsonData = jsonString.data(using: .utf8)!
    
    let result = try ResponseParser.processAPIResponse(jsonData)
    
    #expect(result.jsonData.count > 0)
    #expect(result.binaryData == nil)
    #expect(result.binaryLength == 0)
    
    // Verify JSON content
    let json = try JSONSerialization.jsonObject(with: result.jsonData) as? [String: Any]
    #expect(json?["method"] as? String == "response")
    #expect(json?["status"] as? String == "ok")
}

@Test("ResponseParser processes JSON with binary tail")
func testProcessJSONWithBinary() async throws {
    let jsonString = #"{"image":"thumbnail"}"#
    let binaryData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]) // JPEG header
    var combined = jsonString.data(using: .utf8)!
    combined.append(binaryData)
    
    let result = try ResponseParser.processAPIResponse(combined)
    
    #expect(result.jsonData.count > 0)
    #expect(result.binaryData != nil)
    #expect(result.binaryLength == 6)
    #expect(result.binaryData == binaryData)
}

@Test("ResponseParser handles empty binary tail")
func testProcessJSONWithEmptyTail() async throws {
    let jsonString = #"{"data":"value"}"#
    let jsonData = jsonString.data(using: .utf8)!
    
    let result = try ResponseParser.processAPIResponse(jsonData)
    
    #expect(result.jsonData.count > 0)
    #expect(result.binaryData == nil)
}

@Test("ResponseParser throws on completely invalid data")
func testProcessInvalidData() async throws {
    let invalidData = Data([0xFF, 0xFE, 0xFD, 0xFC])
    
    #expect(throws: ResponseParseError.self) {
        _ = try ResponseParser.processAPIResponse(invalidData)
    }
}

@Test("KEY_FACTORY is available in KeyCode enum")
func testFactoryKeyCode() async throws {
    #expect(KeyCode.factory.rawValue == "KEY_FACTORY")
}
