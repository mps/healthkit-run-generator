import Foundation

/// Aggregate metrics for a complete generated run.
public struct RunMetrics: Sendable {
    /// Total distance in meters
    public let totalDistance: Double

    /// Total duration in seconds
    public let totalDuration: TimeInterval

    /// Average pace in seconds per mile
    public var averagePacePerMile: Double {
        guard totalDistance > 0 else { return 0 }
        return totalDuration / (totalDistance / 1609.344)
    }

    /// Average pace in seconds per kilometer
    public var averagePacePerKilometer: Double {
        guard totalDistance > 0 else { return 0 }
        return totalDuration / (totalDistance / 1000.0)
    }

    /// Average heart rate (bpm)
    public let averageHeartRate: Double

    /// Max heart rate (bpm)
    public let maxHeartRate: Double

    /// Average cadence (steps per minute)
    public let averageCadence: Double

    /// Total elevation gain in meters
    public let totalElevationGain: Double

    /// Total elevation loss in meters
    public let totalElevationLoss: Double

    /// Total active calories burned
    public let totalCalories: Double

    /// Per-split breakdown
    public let splits: [SplitData]

    public init(
        totalDistance: Double,
        totalDuration: TimeInterval,
        averageHeartRate: Double,
        maxHeartRate: Double,
        averageCadence: Double,
        totalElevationGain: Double = 0,
        totalElevationLoss: Double = 0,
        totalCalories: Double = 0,
        splits: [SplitData] = []
    ) {
        self.totalDistance = totalDistance
        self.totalDuration = totalDuration
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.averageCadence = averageCadence
        self.totalElevationGain = totalElevationGain
        self.totalElevationLoss = totalElevationLoss
        self.totalCalories = totalCalories
        self.splits = splits
    }
}

extension RunMetrics: CustomStringConvertible {
    public var description: String {
        let paceMin = Int(averagePacePerMile) / 60
        let paceSec = Int(averagePacePerMile) % 60
        let durMin = Int(totalDuration) / 60
        let durSec = Int(totalDuration) % 60
        return """
        Run: \(String(format: "%.2f", totalDistance / 1609.344)) mi in \(durMin):\(String(format: "%02d", durSec))
        Pace: \(paceMin):\(String(format: "%02d", paceSec))/mi | HR: \(String(format: "%.0f", averageHeartRate)) avg / \(String(format: "%.0f", maxHeartRate)) max
        Cadence: \(String(format: "%.0f", averageCadence)) spm | Calories: \(String(format: "%.0f", totalCalories))
        Elevation: +\(String(format: "%.0f", totalElevationGain))m / -\(String(format: "%.0f", totalElevationLoss))m
        Splits: \(splits.count)
        """
    }
}
