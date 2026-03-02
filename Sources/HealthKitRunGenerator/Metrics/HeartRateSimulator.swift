import Foundation

/// Simulates realistic heart rate progression during a run.
struct HeartRateSimulator {
    let restingHR: Double
    let maxHR: Double
    let hrZone: (lower: Double, upper: Double)

    /// Generate heart rate samples for a run.
    /// - Parameters:
    ///   - duration: Total run duration in seconds
    ///   - sampleInterval: Seconds between samples (default 5s like Apple Watch)
    ///   - rng: Random number generator
    /// - Returns: Array of (offset, bpm) tuples
    func simulate(
        duration: TimeInterval,
        sampleInterval: TimeInterval = 5.0,
        rng: inout RunRNG
    ) -> (samples: [(offset: TimeInterval, bpm: Double)], average: Double, max: Double) {
        var samples: [(TimeInterval, Double)] = []
        let targetLow = maxHR * hrZone.lower
        let targetHigh = maxHR * hrZone.upper
        let targetMid = (targetLow + targetHigh) / 2.0
        let warmupDuration = min(duration * 0.1, 300) // 10% or 5 min max
        let cooldownStart = duration * 0.92

        var currentHR = restingHR + 20 // starting HR (light warmup assumed)
        var peakHR = currentHR
        var totalHR = 0.0
        var count = 0

        var offset: TimeInterval = 0
        while offset <= duration {
            let fraction = offset / duration
            let target: Double

            if offset < warmupDuration {
                // Warmup: ramp from starting HR to target zone
                let warmupFraction = offset / warmupDuration
                target = currentHR + (targetMid - currentHR) * warmupFraction
            } else if offset > cooldownStart {
                // Cooldown: drift back down
                let cooldownFraction = (offset - cooldownStart) / (duration - cooldownStart)
                target = targetMid - (targetMid - restingHR - 15) * cooldownFraction
            } else {
                // Steady state with cardiac drift (HR slowly rises over time)
                let driftFraction = (offset - warmupDuration) / (cooldownStart - warmupDuration)
                let drift = (targetHigh - targetLow) * 0.6 * driftFraction
                target = targetLow + drift
            }

            // Add natural variability
            let noise = rng.gaussian(mean: 0, stddev: 2.0)
            currentHR = target + noise

            // Clamp to physiological bounds
            currentHR = max(restingHR, min(maxHR, currentHR))
            peakHR = max(peakHR, currentHR)
            totalHR += currentHR
            count += 1

            samples.append((offset, currentHR.rounded()))
            offset += sampleInterval
        }

        let avgHR = count > 0 ? totalHR / Double(count) : targetMid
        return (samples, avgHR, peakHR)
    }
}
