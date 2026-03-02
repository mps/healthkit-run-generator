import Foundation

/// Predefined week-level configuration profiles for batch generation.
/// Each profile defines a mix of run types and distances appropriate for a training focus.
public enum ConfigurationProfile: String, Sendable, Codable, CaseIterable {
    case easyWeek
    case thresholdWeek
    case longRunFocused
    case speedWork
    case recoveryWeek
    case balanced

    /// Run templates: (profile, distance fraction of base mileage, day offset)
    var runTemplates: [(profile: RunProfile, distanceFraction: Double)] {
        switch self {
        case .easyWeek:
            return [
                (.easyRun, 0.15), (.easyRun, 0.18), (.easyRun, 0.15),
                (.easyRun, 0.20), (.longRun, 0.32)
            ]
        case .thresholdWeek:
            return [
                (.easyRun, 0.15), (.tempoRun, 0.18), (.easyRun, 0.12),
                (.tempoRun, 0.15), (.easyRun, 0.12), (.longRun, 0.28)
            ]
        case .longRunFocused:
            return [
                (.easyRun, 0.12), (.easyRun, 0.14), (.tempoRun, 0.12),
                (.easyRun, 0.12), (.longRun, 0.50)
            ]
        case .speedWork:
            return [
                (.easyRun, 0.15), (.intervalRun, 0.15), (.easyRun, 0.12),
                (.intervalRun, 0.15), (.easyRun, 0.12), (.longRun, 0.31)
            ]
        case .recoveryWeek:
            return [
                (.easyRun, 0.20), (.easyRun, 0.20), (.easyRun, 0.25),
                (.easyRun, 0.35)
            ]
        case .balanced:
            return [
                (.easyRun, 0.15), (.tempoRun, 0.15), (.easyRun, 0.12),
                (.intervalRun, 0.13), (.easyRun, 0.12), (.longRun, 0.33)
            ]
        }
    }

    /// Human-readable description
    public var displayName: String {
        switch self {
        case .easyWeek: return "Easy Week"
        case .thresholdWeek: return "Threshold Week"
        case .longRunFocused: return "Long Run Focused"
        case .speedWork: return "Speed Work"
        case .recoveryWeek: return "Recovery Week"
        case .balanced: return "Balanced"
        }
    }
}
