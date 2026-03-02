import Foundation

/// Goal race distance for training plan generation.
public enum GoalDistance: String, Sendable, Codable, CaseIterable {
    case fiveK = "5K"
    case tenK = "10K"
    case halfMarathon = "Half Marathon"
    case marathon = "Marathon"

    /// Race distance
    public var distance: Distance {
        switch self {
        case .fiveK: return .kilometers(5)
        case .tenK: return .kilometers(10)
        case .halfMarathon: return .kilometers(21.0975)
        case .marathon: return .kilometers(42.195)
        }
    }

    /// Base weekly mileage (miles) per fitness level for a training plan
    public func weeklyMileage(for level: FitnessLevel) -> Double {
        switch (self, level) {
        case (.fiveK, .beginner):       return 12
        case (.fiveK, .intermediate):   return 20
        case (.fiveK, .advanced):       return 30
        case (.fiveK, .elite):          return 40
        case (.tenK, .beginner):        return 15
        case (.tenK, .intermediate):    return 25
        case (.tenK, .advanced):        return 35
        case (.tenK, .elite):           return 50
        case (.halfMarathon, .beginner):     return 20
        case (.halfMarathon, .intermediate): return 30
        case (.halfMarathon, .advanced):     return 45
        case (.halfMarathon, .elite):        return 60
        case (.marathon, .beginner):         return 25
        case (.marathon, .intermediate):     return 35
        case (.marathon, .advanced):         return 55
        case (.marathon, .elite):            return 75
        }
    }

    /// Number of runs per week per fitness level
    public func runsPerWeek(for level: FitnessLevel) -> Int {
        switch (self, level) {
        case (_, .beginner):     return 4
        case (_, .intermediate): return 5
        case (_, .advanced):     return 5
        case (_, .elite):        return 6
        }
    }
}
