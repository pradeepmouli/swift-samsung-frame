import Foundation

extension Duration {
    /// Creates a duration from milliseconds
    /// - Parameter milliseconds: Number of milliseconds
    /// - Returns: A Duration instance
    public static func milliseconds(_ milliseconds: Int) -> Duration {
        return .milliseconds(Int64(milliseconds))
    }
    
    /// Creates a duration from seconds
    /// - Parameter seconds: Number of seconds
    /// - Returns: A Duration instance
    public static func seconds(_ seconds: Int) -> Duration {
        return .seconds(Int64(seconds))
    }
    
    /// Returns the duration in milliseconds
    public var inMilliseconds: Int {
        let components = self.components
        return Int(components.seconds * 1000) + Int(components.attoseconds / 1_000_000_000_000_000)
    }
}
