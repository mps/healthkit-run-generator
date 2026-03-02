import Foundation

/// Treadmill incline profile for indoor runs.
public enum InclineProfile: Sendable, Codable {
    /// Flat throughout (0% grade)
    case flat
    /// Gradual increase from 0% to max grade
    case progressive(maxGrade: Double)
    /// Alternating between high and low incline
    case interval(highGrade: Double, lowGrade: Double, intervalMinutes: Double)
    /// Constant grade throughout
    case constant(grade: Double)

    /// Grade at a given fraction of the run (0.0 = start, 1.0 = end)
    public func grade(atFraction fraction: Double) -> Double {
        let clamped = max(0, min(1, fraction))
        switch self {
        case .flat:
            return 0
        case .progressive(let maxGrade):
            return maxGrade * clamped
        case .interval(let high, let low, _):
            // Simple alternating: use sin wave to create intervals
            let cycles = 4.0 // number of intervals in the run
            let phase = sin(clamped * cycles * .pi)
            return phase > 0 ? high : low
        case .constant(let grade):
            return grade
        }
    }
}
