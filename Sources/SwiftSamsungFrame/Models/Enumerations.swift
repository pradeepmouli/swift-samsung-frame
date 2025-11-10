import Foundation

/// Connection state of a TV client
public enum ConnectionState: String, Sendable, Codable {
    case disconnected
    case connecting
    case connected
    case authenticating
    case authenticated
    case reconnecting
    case failed
}

/// Features supported by a Samsung TV
public enum TVFeature: String, Sendable, Codable, CaseIterable {
    case remoteControl
    case appManagement
    case artMode
    case deviceInfo
    case channelControl
    case volumeControl
}

/// Samsung TV API version
public enum APIVersion: String, Sendable, Codable {
    case v1 = "1.0"
    case v2 = "2.0"
}

/// Status of an installed application
public enum AppStatus: String, Sendable, Codable {
    case running
    case paused
    case stopped
    case unknown
}

/// Art category for Frame TV art pieces
public enum ArtCategory: String, Sendable, Codable {
    case nature
    case architecture
    case abstract
    case classic
    case modern
    case photography
    case custom
    case unknown
}

/// Image type for art pieces
public enum ImageType: String, Sendable, Codable {
    case jpeg = "image/jpeg"
    case png = "image/png"
}

/// Matte style for art pieces on Frame TVs
public enum MatteStyle: String, Sendable, Codable {
    case none
    case white
    case black
    case beige
    case sand
    case navy
}

/// Photo filter for art pieces
public enum PhotoFilter: String, Sendable, Codable {
    case none
    case vintage
    case blackAndWhite = "black_white"
    case sepia
    case cool
    case warm
}

/// Type of remote command
public enum CommandType: String, Sendable, Codable {
    case keyPress = "click"
    case keyHold = "press"
    case keyRelease = "release"
}

/// Method used for device discovery
public enum DiscoveryMethod: String, Sendable, Codable {
    case mdns
    case ssdp
    case manual
}

/// Scope of authentication token
public enum TokenScope: String, Sendable, Codable {
    case full
    case readOnly = "read_only"
}

/// Remote control key codes
public enum KeyCode: String, Sendable, Codable {
    // Power and Menu
    case power = "KEY_POWER"
    case powerOff = "KEY_POWEROFF"
    case menu = "KEY_MENU"
    case home = "KEY_HOME"
    case source = "KEY_SOURCE"
    
    // Navigation
    case up = "KEY_UP"
    case down = "KEY_DOWN"
    case left = "KEY_LEFT"
    case right = "KEY_RIGHT"
    case enter = "KEY_ENTER"
    case back = "KEY_RETURN"
    case exit = "KEY_EXIT"
    
    // Volume
    case volumeUp = "KEY_VOLUP"
    case volumeDown = "KEY_VOLDOWN"
    case mute = "KEY_MUTE"
    
    // Channel
    case channelUp = "KEY_CHUP"
    case channelDown = "KEY_CHDOWN"
    case channelList = "KEY_CH_LIST"
    
    // Playback
    case play = "KEY_PLAY"
    case pause = "KEY_PAUSE"
    case stop = "KEY_STOP"
    case rewind = "KEY_REWIND"
    case fastForward = "KEY_FF"
    case record = "KEY_REC"
    
    // Numbers
    case key0 = "KEY_0"
    case key1 = "KEY_1"
    case key2 = "KEY_2"
    case key3 = "KEY_3"
    case key4 = "KEY_4"
    case key5 = "KEY_5"
    case key6 = "KEY_6"
    case key7 = "KEY_7"
    case key8 = "KEY_8"
    case key9 = "KEY_9"
    
    // Function keys
    case red = "KEY_RED"
    case green = "KEY_GREEN"
    case yellow = "KEY_YELLOW"
    case blue = "KEY_BLUE"
    
    // Additional controls
    case info = "KEY_INFO"
    case guide = "KEY_GUIDE"
    case tools = "KEY_TOOLS"
    case settings = "KEY_SETTINGS"
    case pictureMode = "KEY_PICTURE_MODE"
    case soundMode = "KEY_SOUND_MODE"
    case sleep = "KEY_SLEEP"
}
