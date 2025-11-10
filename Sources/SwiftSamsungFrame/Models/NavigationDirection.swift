// NavigationDirection - Directional navigation enum
// Used for remote control navigation commands

import Foundation

/// Navigation direction for TV remote control
public enum NavigationDirection: Sendable {
    case up
    case down
    case left
    case right
    
    /// Convert navigation direction to key code
    var keyCode: KeyCode {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        }
    }
}
