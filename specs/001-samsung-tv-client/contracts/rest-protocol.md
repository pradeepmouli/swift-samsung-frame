# REST API Specification

**Date**: 2025-11-09
**Feature**: 001-samsung-tv-client
**Base URL**: `http://<TV_IP>:8001/api/v2/`

## Overview

Samsung TVs expose a REST API on port 8001 for HTTP requests. This API complements the WebSocket interface and is used primarily for:
- Device information queries
- Art image uploads (Frame TVs)
- Application icon retrieval

**Authentication**: Not required for most endpoints. Art upload may require WebSocket connection to be active.

## Endpoints

### Device Information

#### Get Device Details

**Endpoint**: `GET /api/v2/`

**Description**: Retrieve basic TV information.

**Request**:
```http
GET /api/v2/ HTTP/1.1
Host: 192.168.1.100:8001
```

**Response** (200 OK):
```json
{
    "device": {
        "type": "Samsung SmartTV",
        "name": "Samsung Frame TV",
        "modelName": "QN55LS03B",
        "description": "Samsung Frame TV",
        "networkType": "wireless",
        "ssid": "MyWiFiNetwork",
        "ip": "192.168.1.100",
        "firmwareVersion": "T-NKMDEUC-1442.3",
        "id": "uuid:12345678-1234-1234-1234-123456789012",
        "resolution": "3840x2160",
        "countryCode": "US",
        "msfVersion": "2.0.25",
        "smartHubAgreement": "true",
        "wifiMac": "AA:BB:CC:DD:EE:FF",
        "voiceSupported": "true"
    },
    "type": "Samsung SmartTV",
    "name": "Samsung Frame TV",
    "version": "14.0",
    "isSupport": {
        "DMP_DRM_PLAYREADY": "false",
        "DMP_DRM_WIDEVINE": "false",
        "eden.lowlevel.api": "true",
        "voice_support": "true",
        "art_mode": "true"
    }
}
```

**Error Response** (404 Not Found):
```json
{
    "status": 404,
    "message": "Device not found"
}
```

#### Get Network Configuration

**Endpoint**: `GET /api/v2/network`

**Response** (200 OK):
```json
{
    "networkType": "wireless",
    "mac": "AA:BB:CC:DD:EE:FF",
    "ip": "192.168.1.100",
    "gateway": "192.168.1.1",
    "subnet": "255.255.255.0",
    "dns": ["8.8.8.8", "8.8.4.4"]
}
```

---

### Application Management

#### Get Application Icon

**Endpoint**: `GET /api/v2/applications/{appId}/icon`

**Path Parameters**:
- `appId`: Application identifier (e.g., `111299001912`)

**Request**:
```http
GET /api/v2/applications/111299001912/icon HTTP/1.1
Host: 192.168.1.100:8001
Accept: image/png
```

**Response** (200 OK):
- **Content-Type**: `image/png`
- **Body**: Binary PNG image data

**Error Response** (404 Not Found):
```json
{
    "status": 404,
    "message": "Application not found"
}
```

---

### Art Mode (Frame TV)

#### Check Art Mode Support

**Endpoint**: `GET /api/v2/art/supported`

**Response** (200 OK):
```json
{
    "supported": true,
    "version": "2.1"
}
```

**Response** (200 OK - Not Supported):
```json
{
    "supported": false
}
```

#### Get Art Thumbnail

**Endpoint**: `GET /api/v2/art/{contentId}/thumbnail`

**Path Parameters**:
- `contentId`: Art piece identifier (e.g., `MY-F0001`)

**Request**:
```http
GET /api/v2/art/MY-F0001/thumbnail HTTP/1.1
Host: 192.168.1.100:8001
Accept: image/jpeg
```

**Response** (200 OK):
- **Content-Type**: `image/jpeg`
- **Body**: Binary JPEG thumbnail (typically 256x256 or 512x512)

**Error Response** (404 Not Found):
```json
{
    "status": 404,
    "message": "Art not found"
}
```

#### Upload Art Image

**Endpoint**: `POST /api/v2/art/upload`

**Request**:
```http
POST /api/v2/art/upload HTTP/1.1
Host: 192.168.1.100:8001
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW

------WebKitFormBoundary7MA4YWxkTrZu0gW
Content-Disposition: form-data; name="file"; filename="sunset.jpg"
Content-Type: image/jpeg

[BINARY IMAGE DATA]
------WebKitFormBoundary7MA4YWxkTrZu0gW
Content-Disposition: form-data; name="matte"

modern_matte_grey
------WebKitFormBoundary7MA4YWxkTrZu0gW
Content-Disposition: form-data; name="title"

Sunset Beach
------WebKitFormBoundary7MA4YWxkTrZu0gW--
```

**Form Fields**:
- `file`: Image file (JPEG or PNG, required)
- `matte`: Matte style identifier (optional)
- `title`: Art title (optional)

**Response** (201 Created):
```json
{
    "status": "success",
    "content_id": "MY-F0042",
    "category": "MY_F",
    "thumbnail": "/api/v2/art/MY-F0042/thumbnail"
}
```

**Error Response** (400 Bad Request):
```json
{
    "status": 400,
    "message": "Invalid image format. Supported: JPEG, PNG"
}
```

**Error Response** (413 Payload Too Large):
```json
{
    "status": 413,
    "message": "Image too large. Maximum size: 20MB"
}
```

**Error Response** (503 Service Unavailable):
```json
{
    "status": 503,
    "message": "Art Mode not active or WebSocket connection required"
}
```

**Size Limits**:
- Maximum file size: 20MB
- Recommended resolution: 3840x2160 (4K)
- Supported formats: JPEG, PNG

#### Get Available Mattes

**Endpoint**: `GET /api/v2/art/mattes`

**Response** (200 OK):
```json
{
    "mattes": [
        {
            "id": "modern_matte_white",
            "name": "Modern White",
            "category": "modern"
        },
        {
            "id": "modern_matte_grey",
            "name": "Modern Grey",
            "category": "modern"
        },
        {
            "id": "classic_wood_light",
            "name": "Classic Light Wood",
            "category": "classic"
        }
    ]
}
```

#### Apply Photo Filter

**Endpoint**: `POST /api/v2/art/{contentId}/filter`

**Path Parameters**:
- `contentId`: Art piece identifier

**Request Body**:
```json
{
    "filter": "grayscale"
}
```

**Available Filters**:
- `original`: No filter
- `grayscale`: Black and white
- `vintage`: Vintage film effect
- `warm`: Warm color tone
- `cool`: Cool color tone

**Response** (200 OK):
```json
{
    "status": "success",
    "content_id": "MY-F0042",
    "filter": "grayscale"
}
```

---

## Error Codes

| Code | Message | Description |
|------|---------|-------------|
| 200 | OK | Request successful |
| 201 | Created | Resource created successfully |
| 400 | Bad Request | Invalid request parameters |
| 401 | Unauthorized | Authentication required |
| 403 | Forbidden | Access denied |
| 404 | Not Found | Resource not found |
| 413 | Payload Too Large | Request body exceeds size limit |
| 500 | Internal Server Error | Server error |
| 503 | Service Unavailable | Service temporarily unavailable |

## Rate Limiting

**Limits**:
- General API: 60 requests per minute
- Art upload: 5 uploads per minute
- Icon retrieval: 30 requests per minute

**Response Headers**:
```http
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1699565460
```

**Error Response** (429 Too Many Requests):
```json
{
    "status": 429,
    "message": "Rate limit exceeded. Retry after 30 seconds.",
    "retry_after": 30
}
```

## Implementation Notes

### URLSession Configuration

```swift
let config = URLSessionConfiguration.default
config.timeoutIntervalForRequest = 10.0
config.timeoutIntervalForResource = 30.0
config.requestCachePolicy = .reloadIgnoringLocalCacheData

let session = URLSession(configuration: config)
```

### Content-Type Headers

- JSON requests: `Content-Type: application/json`
- Image uploads: `Content-Type: multipart/form-data`
- Responses: `Content-Type: application/json` or image type

### Error Handling Pattern

```swift
func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw TVError.invalidResponse
    }

    switch httpResponse.statusCode {
    case 200...299:
        return try JSONDecoder().decode(T.self, from: data)
    case 404:
        throw TVError.deviceNotFound
    case 429:
        throw TVError.rateLimitExceeded
    case 500...599:
        throw TVError.serverError
    default:
        throw TVError.httpError(statusCode: httpResponse.statusCode)
    }
}
```

### Image Upload Implementation

```swift
func uploadArt(imageData: Data, matte: String?) async throws -> String {
    var request = URLRequest(url: uploadURL)
    request.httpMethod = "POST"

    let boundary = "Boundary-\(UUID().uuidString)"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var body = Data()

    // Add image file
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\"art.jpg\"\r\n".data(using: .utf8)!)
    body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
    body.append(imageData)
    body.append("\r\n".data(using: .utf8)!)

    // Add matte if provided
    if let matte = matte {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"matte\"\r\n\r\n".data(using: .utf8)!)
        body.append(matte.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
    }

    body.append("--\(boundary)--\r\n".data(using: .utf8)!)

    request.httpBody = body

    let response: UploadResponse = try await performRequest(request)
    return response.content_id
}
```

### Timeouts

- Connection timeout: 10 seconds
- Read timeout: 30 seconds (longer for image uploads)
- Upload timeout: 60 seconds for large images

### Retry Logic

- Connection failures: Retry up to 2 times with 1-second delay
- 5xx errors: Retry once after 2 seconds
- 429 Rate Limit: Respect `Retry-After` header
- 4xx errors: Do not retry (client error)

## Testing Endpoints

### Mock Server Responses

For testing without physical TV:

**Device Info Mock**:
```json
{
    "device": {
        "modelName": "MockTV",
        "name": "Test TV",
        "id": "uuid:test-1234"
    },
    "isSupport": {
        "art_mode": "true"
    }
}
```

### Integration Tests

Test scenarios:
1. Device info retrieval
2. Application icon download
3. Art mode support check
4. Art thumbnail retrieval
5. Art upload (success and error cases)
6. Rate limiting behavior
7. Network error handling

## Platform Differences

### macOS/iOS/tvOS
- Full support for all endpoints
- URLSession with native multipart encoding

### watchOS
- Device info: ✅ Supported
- Icon retrieval: ✅ Supported
- Art upload: ❌ Limited (memory constraints)
- Recommendation: Disable art upload on watchOS

## References

- Samsung Smart TV API documentation
- HTTP/1.1 specification (RFC 7230-7235)
- Multipart form-data (RFC 2388)
