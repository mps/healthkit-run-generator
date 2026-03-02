import Foundation

/// Metrics for a single split (mile or kilometer).
public struct SplitData: Sendable {
    /// Split index (0-based)
    public let index: Int

    /// Distance of this split in meters
    public let distance: Double

    /// Duration of this split in seconds
    public let duration: TimeInterval

    /// Pace in seconds per mile
    public var pacePerMile: Double {
        guard distance > 0 else { return 0 }
        return duration / (distance / 1609.344)
    }

    /// Pace in seconds per kilometer
    public var pacePerKilometer: Double {
        guard distance > 0 else { return 0 }
        return duration / (distance / 1000.0)
    }

    /// Average heart rate during this split (bpm)
    public let averageHeartRate: Double

    /// Average cadence during this split (steps per minute)
    public let averageCadence: Double

    /// Elevation gain in meters during this split
    public let elevationGain: Double

    /// Elevation loss in meters during this split
    public let elevationLoss: Double

    /// Calories burned during this split
    public let calories: Double

    public init(
        index: Int,
        distance: Double,
        duration: TimeInterval,
        averageHeartRate: Double,
        averageCadence: Double,
        elevationGain: Double = 0,
        elevationLoss: Double = 0,
        calories: Double = 0
    ) {
        self.index = index
        self.distance = distance
        self.duration = duration
        self.averageHeartRate = averageHeartRate
        self.averageCadence = averageCadence
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.calories = calories
    }
}

extension SplitData: CustomStringConvertible {
    public var description: String {
        let minutes = Int(pacePerMile) / 60
        let seconds = Int(pacePerMile) % 60
        return String(format: "Split %d: %d:%02d/mi | HR: %.0f bpm | Cadence: %.0f spm",
                      index + 1, minutes, seconds, averageHeartRate, averageCadence)
    }
}
