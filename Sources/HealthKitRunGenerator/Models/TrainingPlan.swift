import Foundation

/// A complete 4-week training plan with metadata.
public struct TrainingPlan: Sendable {
    /// The fitness level this plan targets
    public let fitnessLevel: FitnessLevel

    /// The goal race distance
    public let goalDistance: GoalDistance

    /// All runs in the plan, ordered by day
    public let runs: [ScheduledRun]

    /// Base seed used for deterministic generation
    public let baseSeed: UInt64

    /// Start date of the plan
    public let startDate: Date

    /// Total number of weeks
    public var weeks: Int { 4 }

    /// Total planned mileage across all 4 weeks
    public var totalMileage: Double {
        runs.reduce(0) { $0 + $1.run.metrics.totalDistance / 1609.344 }
    }

    /// Weekly mileage breakdown
    public var weeklyMileage: [Double] {
        (0..<4).map { week in
            runsForWeek(week).reduce(0) { $0 + $1.run.metrics.totalDistance / 1609.344 }
        }
    }

    /// Intensity distribution as (easy%, tempo%, interval%, longRun%) tuple
    public var intensityDistribution: (easy: Double, tempo: Double, interval: Double, longRun: Double) {
        let total = Double(runs.count)
        guard total > 0 else { return (0, 0, 0, 0) }
        let easy = Double(runs.filter { $0.run.configuration.profile == .easyRun }.count)
        let tempo = Double(runs.filter { $0.run.configuration.profile == .tempoRun }.count)
        let interval = Double(runs.filter { $0.run.configuration.profile == .intervalRun }.count)
        let long = Double(runs.filter { $0.run.configuration.profile == .longRun }.count)
        return (easy / total, tempo / total, interval / total, long / total)
    }

    /// Rest days (days with no run scheduled)
    public var restDays: [Int] {
        let runDays = Set(runs.map { $0.dayIndex })
        return (0..<28).filter { !runDays.contains($0) }.sorted()
    }

    /// Get runs for a specific week (0-indexed)
    public func runsForWeek(_ week: Int) -> [ScheduledRun] {
        let start = week * 7
        let end = start + 7
        return runs.filter { $0.dayIndex >= start && $0.dayIndex < end }
    }

    public init(
        fitnessLevel: FitnessLevel,
        goalDistance: GoalDistance,
        runs: [ScheduledRun],
        baseSeed: UInt64,
        startDate: Date
    ) {
        self.fitnessLevel = fitnessLevel
        self.goalDistance = goalDistance
        self.runs = runs
        self.baseSeed = baseSeed
        self.startDate = startDate
    }
}

/// A single run within a training plan, with scheduling metadata.
public struct ScheduledRun: Sendable {
    /// Day index within the plan (0-27 for a 4-week plan)
    public let dayIndex: Int

    /// Week number (1-4)
    public var week: Int { (dayIndex / 7) + 1 }

    /// Day of week (0 = Monday, 6 = Sunday)
    public var dayOfWeek: Int { dayIndex % 7 }

    /// The generated run
    public let run: GeneratedRun

    /// Intent/purpose of this run
    public let purpose: String

    public init(dayIndex: Int, run: GeneratedRun, purpose: String) {
        self.dayIndex = dayIndex
        self.run = run
        self.purpose = purpose
    }
}

extension TrainingPlan: CustomStringConvertible {
    public var description: String {
        var lines: [String] = []
        lines.append("Training Plan: \(goalDistance.rawValue) (\(fitnessLevel.rawValue))")
        lines.append("Total Mileage: \(String(format: "%.1f", totalMileage)) miles over 4 weeks")
        lines.append("")

        for week in 0..<4 {
            let weekRuns = runsForWeek(week)
            let weekMiles = weeklyMileage[week]
            lines.append("Week \(week + 1) — \(String(format: "%.1f", weekMiles)) miles")
            for sr in weekRuns {
                let miles = sr.run.metrics.totalDistance / 1609.344
                let paceMin = Int(sr.run.metrics.averagePacePerMile) / 60
                let paceSec = Int(sr.run.metrics.averagePacePerMile) % 60
                lines.append("  Day \(sr.dayIndex + 1): \(sr.purpose) — \(String(format: "%.1f", miles)) mi @ \(paceMin):\(String(format: "%02d", paceSec))/mi")
            }
        }
        return lines.joined(separator: "\n")
    }
}
