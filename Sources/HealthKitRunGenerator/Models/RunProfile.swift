import Foundation

/// Predefined run profile presets that configure intensity and duration characteristics.
public enum RunProfile: String, Sendable, Codable, CaseIterable {
    case easyRun
    case tempoRun
    case intervalRun
    case longRun
    case race5K
    case raceHalfMarathon
    case raceMarathon

    /// Heart rate zone as fraction of max HR (lower bound, upper bound)
    public var heartRateZone: (lower: Double, upper: Double) {
        switch self {
        case .easyRun:           return (0.60, 0.70)
        case .tempoRun:          return (0.80, 0.85)
        case .intervalRun:       return (0.60, 0.95) // wide range for intervals
        case .longRun:           return (0.65, 0.75)
        case .race5K:            return (0.85, 0.95)
        case .raceHalfMarathon:  return (0.80, 0.88)
        case .raceMarathon:      return (0.75, 0.85)
        }
    }

    /// Typical duration range in minutes
    public var durationRange: ClosedRange<Double> {
        switch self {
        case .easyRun:           return 30...60
        case .tempoRun:          return 20...40
        case .intervalRun:       return 30...45
        case .longRun:           return 60...150
        case .race5K:            return 15...35
        case .raceHalfMarathon:  return 75...150
        case .raceMarathon:      return 150...300
        }
    }

    /// Whether this profile tends toward negative splits (faster second half)
    public var negativeSplitTendency: Bool {
        switch self {
        case .race5K, .raceHalfMarathon: return true
        default: return false
        }
    }

    /// Pace variation coefficient — how much pace fluctuates around the target
    public var paceVariationCoefficient: Double {
        switch self {
        case .easyRun:           return 0.05
        case .tempoRun:          return 0.03
        case .intervalRun:       return 0.25
        case .longRun:           return 0.06
        case .race5K:            return 0.04
        case .raceHalfMarathon:  return 0.03
        case .raceMarathon:      return 0.04
        }
    }
}
