// Duration Extensions - Helper methods for Duration
// Note: Duration.milliseconds() and Duration.seconds() are already available in Swift 6
// This file provides convenience methods for converting Duration to numeric values

import Foundation

extension Duration {
    /// Get duration in milliseconds
    /// - Returns: Duration as milliseconds (Int64)
    public func milliseconds() -> Int64 {
        let (seconds, attoseconds) = self.components
        return (seconds * 1_000) + (attoseconds / 1_000_000_000_000_000)
    }
    
    /// Get duration in seconds
    /// - Returns: Duration as seconds (Double)
    public func seconds() -> Double {
        let (seconds, attoseconds) = self.components
        return Double(seconds) + (Double(attoseconds) / 1_000_000_000_000_000_000)
    }
}

