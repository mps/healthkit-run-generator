import Foundation

/// A distance value with unit, convertible between miles and kilometers.
public struct Distance: Sendable, Codable {
    /// Distance in meters (canonical storage)
    public let meters: Double

    public var miles: Double { meters / 1609.344 }
    public var kilometers: Double { meters / 1000.0 }

    private init(meters: Double) {
        self.meters = meters
    }

    public static func miles(_ value: Double) -> Distance {
        Distance(meters: value * 1609.344)
    }

    public static func kilometers(_ value: Double) -> Distance {
        Distance(meters: value * 1000.0)
    }

    public static func meters(_ value: Double) -> Distance {
        Distance(meters: value)
    }
}

extension Distance: CustomStringConvertible {
    public var description: String {
        String(format: "%.2f mi (%.2f km)", miles, kilometers)
    }
}
