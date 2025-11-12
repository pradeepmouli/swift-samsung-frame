// NavigationDirection - Directional navigation enum
// Used for remote control navigation commands

import Foundation

/// Navigation direction for TV remote control
public enum NavigationDirection: Sendable, Codable, CustomStringConvertible {
    case up
    case down
    case left
    case right
    
    public var description: String {
        switch self {
        case .up: return "up"
        case .down: return "down"
        case .left: return "left"
        case .right: return "right"
        }
    }
    /// Map direction to remote key code
    public var keyCode: KeyCode {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        }
    }
}
