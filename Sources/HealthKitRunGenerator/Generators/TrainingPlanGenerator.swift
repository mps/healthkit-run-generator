import Foundation

/// Generates realistic 4-week training cycles based on fitness level and goal distance.
///
/// Each plan includes 4-6 runs per week with appropriate periodization:
/// - Week 1: Base building
/// - Week 2: Build (slight increase)
/// - Week 3: Peak volume
/// - Week 4: Recovery/taper (reduced volume)
public struct TrainingPlanGenerator: Sendable {

    public init() {}

    /// Generate a 4-week training plan.
    /// - Parameters:
    ///   - fitnessLevel: Runner's fitness level
    ///   - goalDistance: Target race distance
    ///   - startDate: First day of the plan (defaults to today)
    ///   - baseSeed: Base seed for deterministic generation
    ///   - runType: Indoor or outdoor (default: outdoor)
    ///   - terrain: Terrain type for outdoor runs
    /// - Returns: A complete TrainingPlan with metadata
    public func generate(
        fitnessLevel: FitnessLevel,
        goalDistance: GoalDistance,
        startDate: Date = Date(),
        baseSeed: UInt64 = 1,
        runType: RunType = .outdoor,
        terrain: TerrainType = .flat
    ) -> TrainingPlan {
        let baseMileage = goalDistance.weeklyMileage(for: fitnessLevel)
        let runsPerWeek = goalDistance.runsPerWeek(for: fitnessLevel)

        // Periodization multipliers: build → build → peak → recovery
        let weekMultipliers: [Double] = [1.0, 1.08, 1.15, 0.75]

        let generator: RunGenerator = runType == .outdoor ? OutdoorRunGenerator() : IndoorRunGenerator()
        var allRuns: [ScheduledRun] = []
        var seedCounter: UInt64 = baseSeed

        for week in 0..<4 {
            let weekMileage = baseMileage * weekMultipliers[week]
            let weekSchedule = buildWeekSchedule(
                week: week,
                weekMileage: weekMileage,
                runsPerWeek: runsPerWeek,
                fitnessLevel: fitnessLevel,
                goalDistance: goalDistance
            )

            for entry in weekSchedule {
                let dayIndex = week * 7 + entry.dayOfWeek
                let dayOffset = TimeInterval(dayIndex) * 86400

                // Morning run time: 6:30 AM with slight variation
                var runRNG = RunRNG(seed: seedCounter)
                let hourOffset = runRNG.double(in: 6.0...8.0) * 3600
                let runDate = Calendar.current.startOfDay(
                    for: startDate.addingTimeInterval(dayOffset)
                ).addingTimeInterval(hourOffset)

                let config = RunConfiguration(
                    profile: entry.profile,
                    fitnessLevel: fitnessLevel,
                    distance: .miles(entry.miles),
                    runType: runType,
                    terrain: terrain,
                    startDate: runDate,
                    seed: seedCounter
                )

                let run = generator.generate(config: config)
                allRuns.append(ScheduledRun(
                    dayIndex: dayIndex,
                    run: run,
                    purpose: entry.purpose
                ))

                seedCounter += 1
            }
        }

        return TrainingPlan(
            fitnessLevel: fitnessLevel,
            goalDistance: goalDistance,
            runs: allRuns.sorted { $0.dayIndex < $1.dayIndex },
            baseSeed: baseSeed,
            startDate: startDate
        )
    }

    // MARK: - Private

    private struct WeekEntry {
        let dayOfWeek: Int // 0=Mon, 6=Sun
        let profile: RunProfile
        let miles: Double
        let purpose: String
    }

    private func buildWeekSchedule(
        week: Int,
        weekMileage: Double,
        runsPerWeek: Int,
        fitnessLevel: FitnessLevel,
        goalDistance: GoalDistance
    ) -> [WeekEntry] {
        // Week 4 is recovery — mostly easy runs, shorter long run
        let isRecoveryWeek = (week == 3)
        // Week 3 is peak — longest long run
        let isPeakWeek = (week == 2)

        var entries: [WeekEntry] = []

        // Long run fraction increases with goal distance
        let longRunFraction: Double
        switch goalDistance {
        case .fiveK: longRunFraction = 0.28
        case .tenK: longRunFraction = 0.30
        case .halfMarathon: longRunFraction = 0.35
        case .marathon: longRunFraction = 0.38
        }

        let adjustedLongFraction = isRecoveryWeek ? longRunFraction * 0.7 : longRunFraction
        let longRunMiles = weekMileage * adjustedLongFraction

        // Remaining mileage distributed among other runs
        let remainingMileage = weekMileage - longRunMiles
        let otherRuns = runsPerWeek - 1
        let avgOtherMiles = remainingMileage / Double(max(1, otherRuns))

        // Build the week schedule
        // Long run always on Saturday (day 5) or Sunday (day 6)
        let longRunDay = 6 // Sunday

        entries.append(WeekEntry(
            dayOfWeek: longRunDay,
            profile: .longRun,
            miles: longRunMiles,
            purpose: isPeakWeek ? "Peak long run" : isRecoveryWeek ? "Recovery long run" : "Long run"
        ))

        // Distribute other runs across the week
        let availableDays = [0, 1, 2, 3, 4, 5].filter { $0 != longRunDay }
        let selectedDays = Array(availableDays.prefix(otherRuns))

        for (i, day) in selectedDays.enumerated() {
            let (profile, purpose, milesFraction) = assignRunType(
                dayIndex: i,
                totalOtherRuns: otherRuns,
                week: week,
                isRecoveryWeek: isRecoveryWeek,
                goalDistance: goalDistance,
                fitnessLevel: fitnessLevel
            )

            let miles = avgOtherMiles * milesFraction

            entries.append(WeekEntry(
                dayOfWeek: day,
                profile: profile,
                miles: max(1.0, miles), // Minimum 1 mile
                purpose: purpose
            ))
        }

        return entries
    }

    private func assignRunType(
        dayIndex: Int,
        totalOtherRuns: Int,
        week: Int,
        isRecoveryWeek: Bool,
        goalDistance: GoalDistance,
        fitnessLevel: FitnessLevel
    ) -> (RunProfile, String, Double) {
        if isRecoveryWeek {
            // Recovery week: all easy runs
            return (.easyRun, "Easy recovery", 1.0)
        }

        switch dayIndex {
        case 0:
            return (.easyRun, "Easy run", 0.9)
        case 1:
            // Tempo/threshold day
            if goalDistance == .fiveK {
                return (.intervalRun, "Speed intervals", 0.85)
            }
            return (.tempoRun, "Tempo run", 0.95)
        case 2:
            return (.easyRun, "Easy recovery", 0.8)
        case 3:
            // Second quality session
            if week == 2 {
                // Peak week: add intensity
                return (.intervalRun, "Speed work", 0.85)
            }
            if fitnessLevel == .advanced || fitnessLevel == .elite {
                return (.tempoRun, "Threshold run", 0.9)
            }
            return (.easyRun, "Easy run", 1.0)
        case 4:
            return (.easyRun, "Pre-long-run shakeout", 0.7)
        default:
            return (.easyRun, "Easy run", 0.9)
        }
    }
}
