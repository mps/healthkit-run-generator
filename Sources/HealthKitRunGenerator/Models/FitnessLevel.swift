import Foundation

/// Runner fitness level — drives physiological metric ranges.
public enum FitnessLevel: String, Sendable, Codable, CaseIterable {
    case beginner
    case intermediate
    case advanced
    case elite

    // MARK: - Heart Rate Ranges

    /// Maximum heart rate (bpm)
    public var maxHeartRate: ClosedRange<Int> {
        switch self {
        case .beginner:      return 180...200
        case .intermediate:  return 175...195
        case .advanced:      return 170...190
        case .elite:         return 165...185
        }
    }

    /// Resting heart rate (bpm)
    public var restingHeartRate: ClosedRange<Int> {
        switch self {
        case .beginner:      return 70...80
        case .intermediate:  return 60...70
        case .advanced:      return 50...60
        case .elite:         return 40...50
        }
    }

    // MARK: - Pace Ranges

    /// Easy pace in seconds per mile
    public var easyPacePerMile: ClosedRange<Double> {
        switch self {
        case .beginner:      return 720...840   // 12:00 - 14:00
        case .intermediate:  return 570...660   // 9:30 - 11:00
        case .advanced:      return 450...540   // 7:30 - 9:00
        case .elite:         return 360...420   // 6:00 - 7:00
        }
    }

    /// Tempo pace in seconds per mile
    public var tempoPacePerMile: ClosedRange<Double> {
        switch self {
        case .beginner:      return 600...720   // 10:00 - 12:00
        case .intermediate:  return 480...570   // 8:00 - 9:30
        case .advanced:      return 390...450   // 6:30 - 7:30
        case .elite:         return 300...360   // 5:00 - 6:00
        }
    }

    // MARK: - Cadence

    /// Steps per minute range
    public var cadenceRange: ClosedRange<Int> {
        switch self {
        case .beginner:      return 150...165
        case .intermediate:  return 165...175
        case .advanced:      return 175...185
        case .elite:         return 180...195
        }
    }

    // MARK: - Calories

    /// Approximate calories burned per mile (varies with weight, but useful baseline)
    public var caloriesPerMile: ClosedRange<Double> {
        switch self {
        case .beginner:      return 100...130
        case .intermediate:  return 90...115
        case .advanced:      return 80...105
        case .elite:         return 75...95
        }
    }
}
