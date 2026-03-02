import Foundation

/// Generates realistic outdoor running workout data with GPS routes, elevation, and physiological metrics.
public struct OutdoorRunGenerator: RunGenerator, Sendable {

    public init() {}

    public func generate(config: RunConfiguration) -> GeneratedRun {
        var rng = RunRNG(seed: config.seed)

        let distanceMeters = config.distance.meters
        let splitDistanceMeters = 1609.344 // 1 mile per split
        let splitCount = max(1, Int(ceil(distanceMeters / splitDistanceMeters)))

        // Determine base pace from fitness level and profile
        let basePace = calculateBasePace(config: config, rng: &rng)

        // Generate split paces
        let splitPaces = PaceSimulator.generateSplitPaces(
            splitCount: splitCount,
            basePace: basePace,
            profile: config.profile,
            terrain: config.terrain,
            rng: &rng
        )

        // Calculate total duration from split paces
        var totalDuration: TimeInterval = 0
        var splits: [SplitData] = []

        for i in 0..<splitCount {
            let isLastSplit = (i == splitCount - 1)
            let splitDist = isLastSplit
                ? distanceMeters - Double(i) * splitDistanceMeters
                : splitDistanceMeters
            let pace = splitPaces[i]
            let splitDuration = pace * (splitDist / 1609.344)
            totalDuration += splitDuration
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

        // Cadence simulation
        let baseCadence = Double(rng.int(in: config.fitnessLevel.cadenceRange))
        let cadenceResult = CadenceSimulator.simulate(
            baseCadence: baseCadence,
            basePace: basePace,
            duration: totalDuration,
            splitPaces: splitPaces,
            splitDistance: splitDistanceMeters,
            rng: &rng
        )

        // Route generation
        let startCoord = config.startCoordinate ?? RouteGenerator.defaultStart
        let routePoints = RouteGenerator.generate(
            distance: distanceMeters,
            duration: totalDuration,
            terrain: config.terrain,
            startCoordinate: startCoord,
            rng: &rng
        )

        // Calculate elevation from route
        var totalGain = 0.0
        var totalLoss = 0.0
        for i in 1..<routePoints.count {
            let diff = routePoints[i].altitude - routePoints[i - 1].altitude
            if diff > 0 { totalGain += diff }
            else { totalLoss += abs(diff) }
        }

        // Build splits with metrics
        var elapsedDuration: TimeInterval = 0
        let caloriesPerMile = rng.double(in: config.fitnessLevel.caloriesPerMile)

        for i in 0..<splitCount {
            let isLastSplit = (i == splitCount - 1)
            let splitDist = isLastSplit
                ? distanceMeters - Double(i) * splitDistanceMeters
                : splitDistanceMeters
            let pace = splitPaces[i]
            let splitDuration = pace * (splitDist / 1609.344)

            // Approximate HR and cadence for this split
            let splitMidpoint = elapsedDuration + splitDuration / 2
            let hrAtMid = hrResult.samples.last(where: { $0.0 <= splitMidpoint })?.1 ?? hrResult.average
            let cadAtMid = cadenceResult.samples.last(where: { $0.0 <= splitMidpoint })?.1 ?? cadenceResult.average

            let splitElevGain = totalGain / Double(splitCount) * rng.double(in: 0.5...1.5)
            let splitElevLoss = totalLoss / Double(splitCount) * rng.double(in: 0.5...1.5)
            let splitCals = caloriesPerMile * (splitDist / 1609.344)

            splits.append(SplitData(
                index: i,
                distance: splitDist,
                duration: splitDuration,
                averageHeartRate: hrAtMid,
                averageCadence: cadAtMid,
                elevationGain: splitElevGain,
                elevationLoss: splitElevLoss,
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
            totalElevationGain: totalGain,
            totalElevationLoss: totalLoss,
            totalCalories: totalCalories,
            splits: splits
        )

        return GeneratedRun(
            configuration: config,
            metrics: metrics,
            heartRateSamples: hrResult.samples,
            cadenceSamples: cadenceResult.samples,
            routePoints: routePoints
        )
    }

    // MARK: - Convenience Factory Methods

    /// Generate an easy outdoor run.
    public static func easyRun(
        miles: Double,
        level: FitnessLevel,
        terrain: TerrainType = .flat,
        startDate: Date = Date(),
        seed: UInt64? = nil
    ) -> GeneratedRun {
        let config = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: level,
            distance: .miles(miles),
            runType: .outdoor,
            terrain: terrain,
            startDate: startDate,
            seed: seed
        )
        return OutdoorRunGenerator().generate(config: config)
    }

    /// Generate a tempo outdoor run.
    public static func tempoRun(
        miles: Double,
        level: FitnessLevel,
        terrain: TerrainType = .flat,
        startDate: Date = Date(),
        seed: UInt64? = nil
    ) -> GeneratedRun {
        let config = RunConfiguration(
            profile: .tempoRun,
            fitnessLevel: level,
            distance: .miles(miles),
            runType: .outdoor,
            terrain: terrain,
            startDate: startDate,
            seed: seed
        )
        return OutdoorRunGenerator().generate(config: config)
    }

    /// Generate a long outdoor run.
    public static func longRun(
        miles: Double,
        level: FitnessLevel,
        terrain: TerrainType = .rolling,
        startDate: Date = Date(),
        seed: UInt64? = nil
    ) -> GeneratedRun {
        let config = RunConfiguration(
            profile: .longRun,
            fitnessLevel: level,
            distance: .miles(miles),
            runType: .outdoor,
            terrain: terrain,
            startDate: startDate,
            seed: seed
        )
        return OutdoorRunGenerator().generate(config: config)
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
            // Intervals average between easy and tempo
            let easy = level.easyPacePerMile.lowerBound
            let tempo = level.tempoPacePerMile.upperBound
            return rng.double(in: tempo...easy)
        case .race5K:
            // Faster than tempo
            let lower = level.tempoPacePerMile.lowerBound * 0.92
            let upper = level.tempoPacePerMile.upperBound * 0.95
            return rng.double(in: lower...upper)
        case .raceHalfMarathon:
            // Between tempo and easy
            let lower = level.tempoPacePerMile.lowerBound
            let upper = level.easyPacePerMile.lowerBound
            return rng.double(in: lower...upper)
        case .raceMarathon:
            // Slightly slower than half marathon pace
            let lower = level.tempoPacePerMile.upperBound * 0.98
            let upper = level.easyPacePerMile.lowerBound * 1.02
            return rng.double(in: lower...upper)
        }
    }
}
