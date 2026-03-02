import Foundation

/// Generates multiple runs with deterministic seeds, configuration profiles, and filtering.
public struct BatchRunGenerator: Sendable {

    public init() {}

    /// Filter options for batch generation results.
    public struct FilterOptions: Sendable {
        /// Minimum distance in miles (inclusive)
        public let minDistanceMiles: Double?
        /// Maximum distance in miles (inclusive)
        public let maxDistanceMiles: Double?
        /// Minimum pace in seconds per mile (inclusive — higher = slower)
        public let minPacePerMile: Double?
        /// Maximum pace in seconds per mile (inclusive — lower = faster)
        public let maxPacePerMile: Double?
        /// Filter to specific run types
        public let runType: RunType?
        /// Filter to specific run profiles
        public let profiles: [RunProfile]?

        public init(
            minDistanceMiles: Double? = nil,
            maxDistanceMiles: Double? = nil,
            minPacePerMile: Double? = nil,
            maxPacePerMile: Double? = nil,
            runType: RunType? = nil,
            profiles: [RunProfile]? = nil
        ) {
            self.minDistanceMiles = minDistanceMiles
            self.maxDistanceMiles = maxDistanceMiles
            self.minPacePerMile = minPacePerMile
            self.maxPacePerMile = maxPacePerMile
            self.runType = runType
            self.profiles = profiles
        }
    }

    // MARK: - Seed Range Generation

    /// Generate runs for a range of seeds using a single configuration template.
    /// - Parameters:
    ///   - seedRange: Range of seeds (e.g., 1...100)
    ///   - profile: Run profile preset
    ///   - fitnessLevel: Runner fitness level
    ///   - distance: Target distance
    ///   - runType: Indoor or outdoor
    ///   - terrain: Terrain type (outdoor only)
    ///   - startDate: Base start date (each run offset by seed index * 24h)
    ///   - filter: Optional filter to apply to results
    /// - Returns: Array of GeneratedRun objects
    public func generate(
        seedRange: ClosedRange<UInt64>,
        profile: RunProfile,
        fitnessLevel: FitnessLevel,
        distance: Distance,
        runType: RunType = .outdoor,
        terrain: TerrainType = .flat,
        startDate: Date = Date(),
        filter: FilterOptions? = nil
    ) -> [GeneratedRun] {
        let generator: RunGenerator = runType == .outdoor ? OutdoorRunGenerator() : IndoorRunGenerator()
        var runs: [GeneratedRun] = []

        for seed in seedRange {
            let dayOffset = TimeInterval(seed - seedRange.lowerBound) * 86400
            let config = RunConfiguration(
                profile: profile,
                fitnessLevel: fitnessLevel,
                distance: distance,
                runType: runType,
                terrain: terrain,
                startDate: startDate.addingTimeInterval(dayOffset),
                seed: seed
            )
            let run = generator.generate(config: config)
            runs.append(run)
        }

        if let filter {
            return applyFilter(runs, filter: filter)
        }
        return runs
    }

    // MARK: - Profile-Based Generation

    /// Generate a batch of runs using a configuration profile (e.g., easy week, threshold week).
    /// - Parameters:
    ///   - count: Number of complete cycles to generate
    ///   - configProfile: Week-level configuration profile
    ///   - fitnessLevel: Runner fitness level
    ///   - weeklyMileage: Target weekly mileage in miles
    ///   - runType: Indoor or outdoor
    ///   - terrain: Terrain type (outdoor only)
    ///   - baseSeed: Base seed (each run gets baseSeed + index)
    ///   - startDate: Start date for the first run
    ///   - filter: Optional filter to apply
    /// - Returns: Array of GeneratedRun objects
    public func generate(
        count: Int = 1,
        configProfile: ConfigurationProfile,
        fitnessLevel: FitnessLevel,
        weeklyMileage: Double,
        runType: RunType = .outdoor,
        terrain: TerrainType = .flat,
        baseSeed: UInt64 = 1,
        startDate: Date = Date(),
        filter: FilterOptions? = nil
    ) -> [GeneratedRun] {
        let generator: RunGenerator = runType == .outdoor ? OutdoorRunGenerator() : IndoorRunGenerator()
        let templates = configProfile.runTemplates
        var runs: [GeneratedRun] = []

        for cycle in 0..<count {
            for (i, template) in templates.enumerated() {
                let runIndex = cycle * templates.count + i
                let seed = baseSeed + UInt64(runIndex)
                let dayOffset = TimeInterval(runIndex) * 86400
                let miles = weeklyMileage * template.distanceFraction

                let config = RunConfiguration(
                    profile: template.profile,
                    fitnessLevel: fitnessLevel,
                    distance: .miles(miles),
                    runType: runType,
                    terrain: terrain,
                    startDate: startDate.addingTimeInterval(dayOffset),
                    seed: seed
                )
                let run = generator.generate(config: config)
                runs.append(run)
            }
        }

        if let filter {
            return applyFilter(runs, filter: filter)
        }
        return runs
    }

    // MARK: - JSON Export

    /// Export runs to a JSON-compatible array of dictionaries.
    public static func toJSON(_ runs: [GeneratedRun]) -> [[String: Any]] {
        runs.map { run in
            var dict: [String: Any] = [
                "seed": run.configuration.seed as Any,
                "profile": run.configuration.profile.rawValue,
                "fitnessLevel": run.configuration.fitnessLevel.rawValue,
                "runType": run.configuration.runType.rawValue,
                "distance_miles": run.metrics.totalDistance / 1609.344,
                "distance_meters": run.metrics.totalDistance,
                "duration_seconds": run.metrics.totalDuration,
                "average_pace_per_mile": run.metrics.averagePacePerMile,
                "average_heart_rate": run.metrics.averageHeartRate,
                "max_heart_rate": run.metrics.maxHeartRate,
                "average_cadence": run.metrics.averageCadence,
                "total_calories": run.metrics.totalCalories,
                "elevation_gain_meters": run.metrics.totalElevationGain,
                "elevation_loss_meters": run.metrics.totalElevationLoss,
                "start_date": ISO8601DateFormatter().string(from: run.startDate),
                "end_date": ISO8601DateFormatter().string(from: run.endDate),
            ]

            let splits = run.metrics.splits.map { split -> [String: Any] in
                [
                    "index": split.index,
                    "distance_meters": split.distance,
                    "duration_seconds": split.duration,
                    "pace_per_mile": split.pacePerMile,
                    "average_heart_rate": split.averageHeartRate,
                    "average_cadence": split.averageCadence,
                    "elevation_gain": split.elevationGain,
                    "elevation_loss": split.elevationLoss,
                    "calories": split.calories,
                ]
            }
            dict["splits"] = splits
            return dict
        }
    }

    /// Export runs to JSON Data.
    public static func toJSONData(_ runs: [GeneratedRun], prettyPrinted: Bool = true) -> Data? {
        let json = toJSON(runs)
        let options: JSONSerialization.WritingOptions = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return try? JSONSerialization.data(withJSONObject: json, options: options)
    }

    // MARK: - Private

    private func applyFilter(_ runs: [GeneratedRun], filter: FilterOptions) -> [GeneratedRun] {
        runs.filter { run in
            let miles = run.metrics.totalDistance / 1609.344
            let pace = run.metrics.averagePacePerMile

            if let min = filter.minDistanceMiles, miles < min { return false }
            if let max = filter.maxDistanceMiles, miles > max { return false }
            if let min = filter.minPacePerMile, pace < min { return false }
            if let max = filter.maxPacePerMile, pace > max { return false }
            if let type = filter.runType, run.configuration.runType != type { return false }
            if let profiles = filter.profiles, !profiles.contains(run.configuration.profile) { return false }
            return true
        }
    }
}
