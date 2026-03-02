import Foundation

/// Simulates pace progression across splits, accounting for profile, terrain, and fatigue.
struct PaceSimulator {
    /// Generate per-split pace values in seconds per mile.
    /// - Parameters:
    ///   - splitCount: Number of splits
    ///   - basePace: Target pace in seconds per mile
    ///   - profile: Run profile (affects variation and split strategy)
    ///   - terrain: Terrain type (affects per-split adjustments)
    ///   - rng: Random number generator
    /// - Returns: Array of pace values (seconds per mile) for each split
    static func generateSplitPaces(
        splitCount: Int,
        basePace: Double,
        profile: RunProfile,
        terrain: TerrainType,
        rng: inout RunRNG
    ) -> [Double] {
        guard splitCount > 0 else { return [] }

        var paces: [Double] = []

        for i in 0..<splitCount {
            let fraction = Double(i) / max(1, Double(splitCount - 1))
            var pace = basePace

            // Fatigue effect: pace slows 2-5% over the run
            let fatigueEffect = 1.0 + (0.03 * fraction)
            pace *= fatigueEffect

            // Negative split tendency: faster in second half
            if profile.negativeSplitTendency && fraction > 0.5 {
                let boost = 1.0 - (0.04 * (fraction - 0.5) * 2)
                pace *= boost
            }

            // Terrain variation (simulate hills at semi-random splits)
            if terrain != .flat {
                let hillPhase = sin(Double(i) * 1.8 + 0.5)
                if hillPhase > 0 {
                    pace *= 1.0 + (terrain.uphillPaceFactor - 1.0) * hillPhase
                } else {
                    // Downhill: slightly faster
                    pace *= 1.0 + hillPhase * 0.03
                }
            }

            // Random variation
            let variation = rng.gaussian(mean: 1.0, stddev: profile.paceVariationCoefficient)
            pace *= max(0.85, min(1.15, variation))

            paces.append(pace)
        }

        return paces
    }
}
