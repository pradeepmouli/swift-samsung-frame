# WebSocket Protocol Specification

**Date**: 2025-11-09
**Feature**: 001-samsung-tv-client
**Protocol Version**: Samsung WebSocket API v2

## Connection

### Endpoint

```
wss://<TV_IP>:8001/api/v2/channels/samsung.remote.control?name=<BASE64_NAME>
```

**Parameters**:
- `TV_IP`: Television IP address on local network
- `name`: Base64-encoded client name (e.g., `U3dpZnRDbGllbnQ=` for "SwiftClient")

### TLS Requirements

- Uses self-signed certificate
- Certificate validation MUST be disabled for Samsung TVs
- URLSessionWebSocketTask configuration:
  ```swift
  task.delegate.urlSession(_:didReceive:completionHandler:) {
      completionHandler(.useCredential, URLCredential(...))
  }
  ```

### Connection Parameters

```
?name=<BASE64_NAME>&token=<TOKEN>
```

- `name`: Required, Base64-encoded client identifier
- `token`: Optional on first connect, required on subsequent connections

### Handshake Sequence

1. **Client → Server**: WebSocket upgrade request
2. **Server → Client**: 101 Switching Protocols
3. **Server → Client**: Authentication challenge (if no token or invalid token)
4. **Client**: User approves on TV screen
5. **Server → Client**: Token message
6. **Client**: Store token for future use

## Message Format

All messages are JSON objects.

### General Structure

```json
{
    "method": "ms.channel.emit",
    "params": {
        "event": "EVENT_TYPE",
        "to": "host",
        "data": { /* event-specific payload */ }
    }
}
```

## Authentication

### Authentication Request (Server → Client)

Sent when token is missing or invalid.

```json
{
    "event": "ms.channel.connect",
    "data": {
        "token": "",
        "id": "unique-session-id"
    }
}
```

**Client Action**: Display message to user: "Please approve the connection on your TV"

### Authentication Success (Server → Client)

```json
{
    "event": "ms.channel.connect",
    "data": {
        "token": "AUTH_TOKEN_STRING",
        "id": "unique-session-id",
        "clients": [
            {
                "attributes": {
                    "name": "SwiftClient"
                },
                "connectTime": 1699564800000,
                "deviceName": "SwiftClient",
                "id": "client-uuid",
                "isHost": false
            }
        ]
    }
}
```

**Fields**:
- `token`: Authentication token to store and reuse (string, typically 8-10 chars)
- `id`: Session identifier
- `clients`: Array of connected clients
- `connectTime`: Connection timestamp (milliseconds since epoch)

## Remote Control Commands

### Send Key Press

**Client → Server**:

```json
{
    "method": "ms.remote.control",
    "params": {
        "Cmd": "Click",
        "DataOfCmd": "KEY_CODE",
        "Option": "false",
        "TypeOfRemote": "SendRemoteKey"
    }
}
```

**Fields**:
- `Cmd`: Always `"Click"` for key press
- `DataOfCmd`: Key code string (see Key Codes section)
- `Option`: String `"false"` (not boolean)
- `TypeOfRemote`: Always `"SendRemoteKey"`

**Server → Client** (Acknowledgment):

```json
{
    "event": "ms.remote.control",
    "result": "ok"
}
```

**Error Response**:

```json
{
    "event": "ms.remote.control",
    "result": "error",
    "error": "Invalid key code"
}
```

### Common Key Codes

| Key | Code | Description |
|-----|------|-------------|
| Power | `KEY_POWER` | Toggle power |
| Power Off | `KEY_POWEROFF` | Force power off |
| Volume Up | `KEY_VOLUP` | Increase volume |
| Volume Down | `KEY_VOLDOWN` | Decrease volume |
| Mute | `KEY_MUTE` | Toggle mute |
| Channel Up | `KEY_CHUP` | Next channel |
| Channel Down | `KEY_CHDOWN` | Previous channel |
| Up | `KEY_UP` | Navigate up |
| Down | `KEY_DOWN` | Navigate down |
| Left | `KEY_LEFT` | Navigate left |
| Right | `KEY_RIGHT` | Navigate right |
| Enter | `KEY_ENTER` | Select/confirm |
| Return | `KEY_RETURN` | Back button |
| Exit | `KEY_EXIT` | Exit application |
| Home | `KEY_HOME` | Home screen |
| Menu | `KEY_MENU` | Open menu |
| Source | `KEY_SOURCE` | Input source |
| Info | `KEY_INFO` | Display info |
| Tools | `KEY_TOOLS` | Tools menu |
| 0-9 | `KEY_0` - `KEY_9` | Number keys |
| Red | `KEY_RED` | Color button |
| Green | `KEY_GREEN` | Color button |
| Yellow | `KEY_YELLOW` | Color button |
| Blue | `KEY_BLUE` | Color button |

Full list in `data-model.md` under `KeyCode` enum.

## Application Management

### Launch Application

**Client → Server**:

```json
{
    "method": "ms.channel.emit",
    "params": {
        "event": "ed.apps.launch",
        "to": "host",
        "data": {
            "appId": "APPLICATION_ID",
            "action_type": "NATIVE_LAUNCH"
        }
    }
}
```

**Fields**:
- `appId`: Application identifier (e.g., `"111299001912"` for YouTube, `"3201907018807"` for Netflix)
- `action_type`: Launch method, typically `"NATIVE_LAUNCH"`

**Server → Client** (Success):

```json
{
    "event": "ed.apps.launch",
    "result": "ok"
}
```

### Get Installed Applications

**Client → Server**:

```json
{
    "method": "ms.channel.emit",
    "params": {
        "event": "ed.installedApp.get",
        "to": "host"
    }
}
```

**Server → Client** (Response):

```json
{
    "event": "ed.installedApp.get",
    "data": [
        {
            "appId": "111299001912",
            "app_type": 2,
            "icon": "/path/to/icon.png",
            "is_lock": 0,
            "name": "YouTube",
            "version": "1.0.0"
        },
        {
            "appId": "3201907018807",
            "app_type": 2,
            "icon": "/path/to/icon.png",
            "is_lock": 0,
            "name": "Netflix",
            "version": "2.1.0"
        }
    ]
}
```

**Fields**:
- `appId`: Unique application identifier
- `app_type`: Application type (2 = installed app)
- `icon`: Icon path (relative, use REST API to fetch)
- `is_lock`: Lock status (0 = unlocked, 1 = locked)
- `name`: Human-readable app name
- `version`: App version string

## Art Mode (Frame TV)

### Get Art Mode Status

**Client → Server**:

```json
{
    "method": "ms.channel.emit",
    "params": {
        "event": "art_mode_status",
        "to": "host"
    }
}
```

**Server → Client** (Response):

```json
{
    "event": "art_mode_status",
    "data": {
        "status": "on",
        "current_art_id": "MY-F0001"
    }
}
```

### Get Available Art

**Client → Server**:

```json
{
    "method": "ms.channel.emit",
    "params": {
        "event": "art_list",
        "to": "host",
        "data": {
            "category": "MY"
        }
    }
}
```

**Categories**:
- `"MY"`: User-uploaded art
- `"STORE"`: Samsung Art Store content

**Server → Client** (Response):

```json
{
    "event": "art_list",
    "data": {
        "category": "MY",
        "art_list": [
            {
                "content_id": "MY-F0001",
                "title": "Sunset Beach",
                "category": "MY_F",
                "image_type": "PHOTO",
                "matte_id": "modern_matte_grey",
                "thumbnail": "/api/v2/art/MY-F0001/thumbnail"
            }
        ]
    }
}
```

### Select Art

**Client → Server**:

```json
{
    "method": "ms.channel.emit",
    "params": {
        "event": "art_select",
        "to": "host",
        "data": {
            "content_id": "MY-F0001",
            "show": true
        }
    }
}
```

**Fields**:
- `content_id`: Art piece identifier
- `show`: Boolean, whether to enter Art Mode immediately

### Toggle Art Mode

**Client → Server**:

```json
{
    "method": "ms.channel.emit",
    "params": {
        "event": "art_mode",
        "to": "host",
        "data": {
            "value": "on"
        }
    }
}
```

**Values**: `"on"` or `"off"`

### Delete Art

**Client → Server**:

```json
{
    "method": "ms.channel.emit",
    "params": {
        "event": "art_delete",
        "to": "host",
        "data": {
            "content_id": "MY-F0001"
        }
    }
}
```

**Bulk Delete**:

```json
{
    "method": "ms.channel.emit",
    "params": {
        "event": "art_delete",
        "to": "host",
        "data": {
            "content_ids": ["MY-F0001", "MY-F0002", "MY-F0003"]
        }
    }
}
```

## Device Information

### Get Device Info

**Client → Server**:

```json
{
    "method": "ms.channel.emit",
    "params": {
        "event": "ed.edenTV.info",
        "to": "host"
    }
}
```

**Server → Client** (Response):

```json
{
    "event": "ed.edenTV.info",
    "data": {
        "id": "uuid:12345678-1234-1234-1234-123456789012",
        "name": "Samsung Frame TV",
        "version": "14.0",
        "device": {
            "type": "Samsung SmartTV",
            "modelName": "QN55LS03B",
            "networkType": "wireless",
            "wifiMac": "AA:BB:CC:DD:EE:FF"
        },
        "isSupport": {
            "DMP_DRM_PLAYREADY": "false",
            "DMP_DRM_WIDEVINE": "false",
            "eden.lowlevel.api": "true",
            "voice_support": "true",
            "art_mode": "true"
        }
    }
}
```

## Connection Health

### Ping (Keep-Alive)

Send every 30 seconds to maintain connection.

**Client → Server**:

```json
{
    "method": "ms.channel.emit",
    "params": {
        "event": "ms.channel.ping",
        "to": "host"
    }
}
```

**Server → Client**:

```json
{
    "event": "ms.channel.pong"
}
```

## Error Handling

### Common Error Events

**Connection Unauthorized**:

```json
{
    "event": "ms.channel.unauthorized",
    "data": {
        "message": "Token invalid or expired"
    }
}
```

**Client Action**: Re-authenticate (clear token, reconnect)

**Command Failed**:

```json
{
    "event": "ms.error",
    "data": {
        "message": "Command execution failed",
        "code": 500
    }
}
```

### Connection Close Codes

| Code | Reason | Action |
|------|--------|--------|
| 1000 | Normal closure | Clean disconnect |
| 1001 | Going away | TV shutting down |
| 1006 | Abnormal closure | Network error, retry |
| 4401 | Unauthorized | Re-authenticate |

## Implementation Notes

### Message Ordering

- Messages are processed sequentially
- Wait for acknowledgment before sending next command (or use 100ms delay)

### Connection Lifecycle

1. Connect WebSocket
2. Wait for auth challenge or success
3. Store token on success
4. Start ping timer (30s interval)
5. Send commands as needed
6. Close gracefully on disconnect

### Threading Model

- All WebSocket operations on dedicated serial queue
- Message callbacks dispatched to main actor for UI updates
- Actor-based state management for connection state

### Retry Logic

- Connection failures: Retry up to 3 times with exponential backoff (1s, 2s, 4s)
- Command failures: Retry once after 500ms
- Auth failures: Do not retry automatically, require user action

### Timeouts

- Connection: 3 seconds
- Commands: 5 seconds
- Ping response: 2 seconds (3 missed pings = disconnect)

## Example Flow

### Initial Connection

1. Client connects to `wss://192.168.1.100:8001/api/v2/channels/samsung.remote.control?name=U3dpZnRDbGllbnQ=`
2. Server sends auth challenge (empty token)
3. Client displays "Approve on TV" message
4. User approves on TV screen
5. Server sends token: `{"event":"ms.channel.connect","data":{"token":"ABC12345"}}`
6. Client stores token
7. Connection established

### Subsequent Connection

1. Client connects with stored token: `wss://192.168.1.100:8001/api/v2/channels/samsung.remote.control?name=U3dpZnRDbGllbnQ=&token=ABC12345`
2. Server sends immediate connect success
3. Connection established (no approval needed)

### Sending Command

1. Client sends volume up: `{"method":"ms.remote.control","params":{"Cmd":"Click","DataOfCmd":"KEY_VOLUP","Option":"false","TypeOfRemote":"SendRemoteKey"}}`
2. Server acknowledges: `{"event":"ms.remote.control","result":"ok"}`
3. Volume increases on TV

## References

- Samsung WebSocket API documentation (proprietary)
- Python reference: `samsung-tv-ws-api` library
- Tested against Samsung Frame TV models: LS03B, LS03T series
