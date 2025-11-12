// Enumerations for Samsung TV Client Library
// Defines all core enums used throughout the library

import Foundation

/// Current state of the TV connection
public enum ConnectionState: String, Sendable, Codable {
    case disconnected
    case connecting
    case authenticating
    case connected
    case disconnecting
    case error
}

/// Features supported by Samsung TVs
public enum TVFeature: String, Sendable, Codable {
    case artMode
    case voiceControl
    case ambientMode
    case gameMode
    case multiView
    case screenMirroring
}

/// Samsung TV API version
public enum APIVersion: String, Sendable, Codable {
    case v1 // Encrypted API (J/K series)
    case v2 // Modern WebSocket API (2016+)
}

/// Application running status
public enum AppStatus: String, Sendable, Codable {
    case stopped
    case launching
    case running
    case paused
    case stopping
}

/// Art category classification
public enum ArtCategory: String, Sendable, Codable {
    case preloaded   // Samsung-provided art
    case uploaded    // User-uploaded images
    case purchased   // Art Store purchases
}

/// Supported image formats
public enum ImageType: String, Sendable, Codable {
    case jpeg
    case png
}

/// Available matte styles for Frame TVs
public enum MatteStyle: String, Sendable, Codable {
    case none
    case modernBeige = "modern_beige"
    case modernApricot = "modern_apricot"
    case modernIvory = "modern_ivory"
    case modernBrown = "modern_brown"
    case modernWalnut = "modern_walnut"
    case vintageWhite = "vintage_white"
    case vintageBeige = "vintage_beige"
    case vintageWalnut = "vintage_walnut"
}

/// Photo filters for art pieces
public enum PhotoFilter: String, Sendable, Codable {
    case none
    case ink
    case watercolor
    case pencil
    case pastel
    case comic
    case oilPainting = "oil_painting"
}

/// Remote control command type
public enum CommandType: String, Sendable, Codable {
    case press   // Single key press
    case hold    // Press and hold
    case release // Release held key
}

/// Method used to discover device
public enum DiscoveryMethod: String, Sendable, Codable {
    case ssdp      // SSDP/UPnP discovery
    case mdns      // Bonjour/mDNS discovery
    case manual    // Manually added by IP
}

/// Token permission scopes
public enum TokenScope: String, Sendable, Codable {
    case remoteControl
    case appManagement
    case artMode
    case deviceInfo
}

/// WebSocket channel types exposed by Samsung TVs
public enum WebSocketChannel: Sendable, Codable {
    case remoteControl
    case artApp

    /// Path component for the WebSocket endpoint
    public var path: String {
        switch self {
        case .remoteControl:
            return "/api/v2/channels/samsung.remote.control"
        case .artApp:
            return "/api/v2/channels/com.samsung.art-app"
        }
    }

    /// Suggested subprotocols for the channel handshake
    public var subprotocols: [String] {
        switch self {
        case .remoteControl:
            return ["com.samsung.remote-control"]
        case .artApp:
            return ["com.samsung.art-app"]
        }
    }
}

/// Remote control key codes
public enum KeyCode: String, Sendable, Codable {
    // Power
    case power = "KEY_POWER"
    case powerOff = "KEY_POWEROFF"

    // Volume
    case volumeUp = "KEY_VOLUP"
    case volumeDown = "KEY_VOLDOWN"
    case mute = "KEY_MUTE"

    // Navigation
    case up = "KEY_UP"
    case down = "KEY_DOWN"
    case left = "KEY_LEFT"
    case right = "KEY_RIGHT"
    case enter = "KEY_ENTER"
    case back = "KEY_RETURN"

    // Playback
    case play = "KEY_PLAY"
    case pause = "KEY_PAUSE"
    case stop = "KEY_STOP"
    case rewind = "KEY_REWIND"
    case fastForward = "KEY_FF"

    // Channel
    case channelUp = "KEY_CHUP"
    case channelDown = "KEY_CHDOWN"
    case previousChannel = "KEY_PRECH"

    // Menu
    case menu = "KEY_MENU"
    case home = "KEY_HOME"
    case exit = "KEY_EXIT"
    case source = "KEY_SOURCE"
    case tools = "KEY_TOOLS"

    // Numbers
    case num0 = "KEY_0"
    case num1 = "KEY_1"
    case num2 = "KEY_2"
    case num3 = "KEY_3"
    case num4 = "KEY_4"
    case num5 = "KEY_5"
    case num6 = "KEY_6"
    case num7 = "KEY_7"
    case num8 = "KEY_8"
    case num9 = "KEY_9"
}
