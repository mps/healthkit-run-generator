import Foundation

/// Simulates running cadence correlated with pace and fitness level.
struct CadenceSimulator {
    /// Generate cadence samples correlated with pace.
    /// - Parameters:
    ///   - baseCadence: Base cadence for the runner (spm)
    ///   - basePace: Base pace in seconds per mile
    ///   - duration: Run duration in seconds
    ///   - sampleInterval: Seconds between samples
    ///   - splitPaces: Per-split pace values for correlation
    ///   - splitDistance: Distance per split in meters
    ///   - rng: Random number generator
    static func simulate(
        baseCadence: Double,
        basePace: Double,
        duration: TimeInterval,
        sampleInterval: TimeInterval = 5.0,
        splitPaces: [Double],
        splitDistance: Double,
        rng: inout RunRNG
    ) -> (samples: [(offset: TimeInterval, spm: Double)], average: Double) {
        var samples: [(TimeInterval, Double)] = []
        var totalCadence = 0.0
        var count = 0

        var offset: TimeInterval = 0
        while offset <= duration {
            // Determine which split we're in
            let distanceCovered = offset / duration * (splitDistance * Double(splitPaces.count))
            let splitIndex = min(Int(distanceCovered / splitDistance), splitPaces.count - 1)
            let currentPace = splitIndex >= 0 && splitIndex < splitPaces.count
                ? splitPaces[splitIndex] : basePace

            // Faster pace → higher cadence (inverse relationship)
            let paceRatio = basePace / max(currentPace, 1)
            var cadence = baseCadence * (0.85 + 0.15 * paceRatio)

            // Add natural variability (±3 spm)
            cadence += rng.gaussian(mean: 0, stddev: 1.5)

            // Clamp to reasonable range
            cadence = max(140, min(210, cadence))

            samples.append((offset, cadence.rounded()))
            totalCadence += cadence
            count += 1
            offset += sampleInterval
        }

        let avg = count > 0 ? totalCadence / Double(count) : baseCadence
        return (samples, avg)
    }
}
