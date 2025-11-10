import Foundation

/// Direction for navigation commands
public enum NavigationDirection: String, Sendable, Codable {
    case up
    case down
    case left
    case right
    
    /// The corresponding key code for this navigation direction
    public var keyCode: KeyCode {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        }
    }
}
