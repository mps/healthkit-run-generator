import Foundation

/// A seedable random number generator for deterministic output.
struct SeededRandom: RandomNumberGenerator, @unchecked Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

/// Convenience wrapper that uses either a seeded or system RNG.
struct RunRNG: @unchecked Sendable {
    private var seeded: SeededRandom?

    init(seed: UInt64?) {
        if let seed {
            self.seeded = SeededRandom(seed: seed)
        }
    }

    /// Random Double in range
    mutating func double(in range: ClosedRange<Double>) -> Double {
        if var rng = seeded {
            let result = Double.random(in: range, using: &rng)
            seeded = rng
            return result
        }
        return Double.random(in: range)
    }

    /// Random Int in range
    mutating func int(in range: ClosedRange<Int>) -> Int {
        if var rng = seeded {
            let result = Int.random(in: range, using: &rng)
            seeded = rng
            return result
        }
        return Int.random(in: range)
    }

    /// Gaussian-ish random (Box-Muller approximation) centered on mean with stddev
    mutating func gaussian(mean: Double, stddev: Double) -> Double {
        let u1 = double(in: 0.001...0.999)
        let u2 = double(in: 0.001...0.999)
        let z = (-2.0 * log(u1)).squareRoot() * cos(2.0 * .pi * u2)
        return mean + z * stddev
    }
}
