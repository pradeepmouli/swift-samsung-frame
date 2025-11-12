// NavigationDirection - Directional navigation enum
// Used for remote control navigation commands

import Foundation

/// Navigation direction for TV remote control
///
/// Represents the four directional navigation inputs (up, down, left, right)
/// used for TV menu navigation and UI control.
///
/// Example usage:
/// ```swift
/// try await client.remote.navigate(.up)
/// try await client.remote.navigate(.down)
/// ```
public enum NavigationDirection: Sendable, Codable, CustomStringConvertible {
    /// Navigate upward in the UI
    case up
    /// Navigate downward in the UI
    case down
    /// Navigate left in the UI
    case left
    /// Navigate right in the UI
    case right

    /// String representation of the direction
    public var description: String {
        switch self {
        case .up: return "up"
        case .down: return "down"
        case .left: return "left"
        case .right: return "right"
        }
    }
    
    /// Maps navigation direction to the corresponding remote control key code
    /// - Returns: KeyCode for the directional button
    public var keyCode: KeyCode {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        }
    }
}
