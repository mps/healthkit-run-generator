import Foundation

/// Generates realistic indoor (treadmill) running workout data.
/// No GPS route — produces heart rate, cadence, and pace data with incline effects.
public struct IndoorRunGenerator: RunGenerator, Sendable {

    public init() {}

    public func generate(config: RunConfiguration) -> GeneratedRun {
        var rng = RunRNG(seed: config.seed)

        let distanceMeters = config.distance.meters
        let splitDistanceMeters = 1609.344 // 1 mile per split
        let splitCount = max(1, Int(ceil(distanceMeters / splitDistanceMeters)))

        // Base pace — treadmill runs tend to be more consistent
        let basePace = calculateBasePace(config: config, rng: &rng)

        // Generate split paces with treadmill characteristics
        let splitPaces = generateTreadmillSplitPaces(
            splitCount: splitCount,
            basePace: basePace,
            profile: config.profile,
            inclineProfile: config.inclineProfile,
            rng: &rng
        )

        // Calculate total duration
        var totalDuration: TimeInterval = 0
        for i in 0..<splitCount {
            let isLastSplit = (i == splitCount - 1)
            let splitDist = isLastSplit
                ? distanceMeters - Double(i) * splitDistanceMeters
                : splitDistanceMeters
            totalDuration += splitPaces[i] * (splitDist / 1609.344)
        }

        // Heart rate simulation
        let maxHR = Double(rng.int(in: config.fitnessLevel.maxHeartRate))
        let restingHR = Double(rng.int(in: config.fitnessLevel.restingHeartRate))
        let hrSim = HeartRateSimulator(
            restingHR: restingHR,
            maxHR: maxHR,
            hrZone: config.profile.heartRateZone
        )
        let hrResult = hrSim.simulate(duration: totalDuration, rng: &rng)

        // Cadence — more consistent on treadmill
        let baseCadence = Double(rng.int(in: config.fitnessLevel.cadenceRange))
        let cadenceResult = simulateTreadmillCadence(
            baseCadence: baseCadence,
            basePace: basePace,
            duration: totalDuration,
            splitPaces: splitPaces,
            splitDistance: splitDistanceMeters,
            rng: &rng
        )

        // Build splits — no elevation for indoor runs
        var splits: [SplitData] = []
        var elapsedDuration: TimeInterval = 0

        // Treadmill calorie adjustment: ~5% fewer calories (no wind resistance)
        let baseCalPerMile = rng.double(in: config.fitnessLevel.caloriesPerMile)
        let treadmillCalPerMile = baseCalPerMile * 0.95

        // Incline increases calorie burn
        for i in 0..<splitCount {
            let isLastSplit = (i == splitCount - 1)
            let splitDist = isLastSplit
                ? distanceMeters - Double(i) * splitDistanceMeters
                : splitDistanceMeters
            let pace = splitPaces[i]
            let splitDuration = pace * (splitDist / 1609.344)

            let splitMidpoint = elapsedDuration + splitDuration / 2
            let hrAtMid = hrResult.samples.last(where: { $0.0 <= splitMidpoint })?.1 ?? hrResult.average
            let cadAtMid = cadenceResult.samples.last(where: { $0.0 <= splitMidpoint })?.1 ?? cadenceResult.average

            // Incline calorie bonus: ~10% per 1% grade
            let splitFraction = (Double(i) + 0.5) / Double(splitCount)
            let grade = config.inclineProfile.grade(atFraction: splitFraction)
            let inclineBonus = 1.0 + (grade * 0.10)
            let splitCals = treadmillCalPerMile * (splitDist / 1609.344) * inclineBonus

            splits.append(SplitData(
                index: i,
                distance: splitDist,
                duration: splitDuration,
                averageHeartRate: hrAtMid,
                averageCadence: cadAtMid,
                elevationGain: 0,  // indoor: no real elevation
                elevationLoss: 0,
                calories: splitCals
            ))

            elapsedDuration += splitDuration
        }

        let totalCalories = splits.reduce(0) { $0 + $1.calories }

        let metrics = RunMetrics(
            totalDistance: distanceMeters,
            totalDuration: totalDuration,
            averageHeartRate: hrResult.average,
            maxHeartRate: hrResult.max,
            averageCadence: cadenceResult.average,
            totalElevationGain: 0,
            totalElevationLoss: 0,
            totalCalories: totalCalories,
            splits: splits
        )

        // No route points for indoor runs
        return GeneratedRun(
            configuration: config,
            metrics: metrics,
            heartRateSamples: hrResult.samples,
            cadenceSamples: cadenceResult.samples,
            routePoints: []
        )
    }

    // MARK: - Convenience Factory Methods

    /// Generate an easy treadmill run.
    public static func easyRun(
        miles: Double,
        level: FitnessLevel,
        incline: InclineProfile = .flat,
        startDate: Date = Date(),
        seed: UInt64? = nil
    ) -> GeneratedRun {
        let config = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: level,
            distance: .miles(miles),
            runType: .indoor,
            inclineProfile: incline,
            startDate: startDate,
            seed: seed
        )
        return IndoorRunGenerator().generate(config: config)
    }

    /// Generate a tempo treadmill run.
    public static func tempoRun(
        miles: Double,
        level: FitnessLevel,
        incline: InclineProfile = .flat,
        startDate: Date = Date(),
        seed: UInt64? = nil
    ) -> GeneratedRun {
        let config = RunConfiguration(
            profile: .tempoRun,
            fitnessLevel: level,
            distance: .miles(miles),
            runType: .indoor,
            inclineProfile: incline,
            startDate: startDate,
            seed: seed
        )
        return IndoorRunGenerator().generate(config: config)
    }

    /// Generate a treadmill interval run.
    public static func intervalRun(
        miles: Double,
        level: FitnessLevel,
        incline: InclineProfile = .interval(highGrade: 4.0, lowGrade: 1.0, intervalMinutes: 2.0),
        startDate: Date = Date(),
        seed: UInt64? = nil
    ) -> GeneratedRun {
        let config = RunConfiguration(
            profile: .intervalRun,
            fitnessLevel: level,
            distance: .miles(miles),
            runType: .indoor,
            inclineProfile: incline,
            startDate: startDate,
            seed: seed
        )
        return IndoorRunGenerator().generate(config: config)
    }

    // MARK: - Private

    private func calculateBasePace(config: RunConfiguration, rng: inout RunRNG) -> Double {
        let level = config.fitnessLevel
        let profile = config.profile

        switch profile {
        case .easyRun, .longRun:
            return rng.double(in: level.easyPacePerMile)
        case .tempoRun:
            return rng.double(in: level.tempoPacePerMile)
        case .intervalRun:
            let easy = level.easyPacePerMile.lowerBound
            let tempo = level.tempoPacePerMile.upperBound
            return rng.double(in: tempo...easy)
        case .race5K:
            let lower = level.tempoPacePerMile.lowerBound * 0.92
            let upper = level.tempoPacePerMile.upperBound * 0.95
            return rng.double(in: lower...upper)
        case .raceHalfMarathon:
            let lower = level.tempoPacePerMile.lowerBound
            let upper = level.easyPacePerMile.lowerBound
            return rng.double(in: lower...upper)
        case .raceMarathon:
            let lower = level.tempoPacePerMile.upperBound * 0.98
            let upper = level.easyPacePerMile.lowerBound * 1.02
            return rng.double(in: lower...upper)
        }
    }

    /// Treadmill split paces — more consistent than outdoor, but affected by incline.
    private func generateTreadmillSplitPaces(
        splitCount: Int,
        basePace: Double,
        profile: RunProfile,
        inclineProfile: InclineProfile,
        rng: inout RunRNG
    ) -> [Double] {
        guard splitCount > 0 else { return [] }

        var paces: [Double] = []

        for i in 0..<splitCount {
            let fraction = Double(i) / max(1, Double(splitCount - 1))
            var pace = basePace

            // Treadmill: less fatigue effect than outdoor (controlled environment)
            let fatigueEffect = 1.0 + (0.015 * fraction)
            pace *= fatigueEffect

            // Incline effect: higher grade → slower pace
            let grade = inclineProfile.grade(atFraction: fraction)
            let inclineEffect = 1.0 + (grade * 0.035) // ~3.5% slower per 1% grade
            pace *= inclineEffect

            // Treadmill has less random variation (belt speed is set)
            let variation = rng.gaussian(mean: 1.0, stddev: 0.01)
            pace *= max(0.95, min(1.05, variation))

            paces.append(pace)
        }

        return paces
    }

    /// Treadmill cadence — tighter distribution than outdoor.
    private func simulateTreadmillCadence(
        baseCadence: Double,
        basePace: Double,
        duration: TimeInterval,
        splitPaces: [Double],
        splitDistance: Double,
        rng: inout RunRNG
    ) -> (samples: [(offset: TimeInterval, spm: Double)], average: Double) {
        // Treadmill cadence is more uniform — use tighter stddev
        var samples: [(TimeInterval, Double)] = []
        var totalCadence = 0.0
        var count = 0
        let sampleInterval: TimeInterval = 5.0

        var offset: TimeInterval = 0
        while offset <= duration {
            let distanceCovered = offset / duration * (splitDistance * Double(splitPaces.count))
            let splitIndex = min(Int(distanceCovered / splitDistance), splitPaces.count - 1)
            let currentPace = splitIndex >= 0 && splitIndex < splitPaces.count
                ? splitPaces[splitIndex] : basePace

            let paceRatio = basePace / max(currentPace, 1)
            var cadence = baseCadence * (0.9 + 0.1 * paceRatio)

            // Tighter variation on treadmill (±1.5 spm)
            cadence += rng.gaussian(mean: 0, stddev: 0.8)
            cadence = max(145, min(205, cadence))

            samples.append((offset, cadence.rounded()))
            totalCadence += cadence
            count += 1
            offset += sampleInterval
        }

        let avg = count > 0 ? totalCadence / Double(count) : baseCadence
        return (samples, avg)
    }
}
