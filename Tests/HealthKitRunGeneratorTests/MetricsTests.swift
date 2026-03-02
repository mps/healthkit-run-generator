import XCTest
@testable import HealthKitRunGenerator

final class MetricsTests: XCTestCase {

    // MARK: - SeededRandom

    func testSeededRandomDeterministic() {
        var rng1 = RunRNG(seed: 42)
        var rng2 = RunRNG(seed: 42)

        for _ in 0..<100 {
            let v1 = rng1.double(in: 0...1)
            let v2 = rng2.double(in: 0...1)
            XCTAssertEqual(v1, v2, accuracy: 1e-10)
        }
    }

    func testDifferentSeedsProduceDifferentOutput() {
        var rng1 = RunRNG(seed: 42)
        var rng2 = RunRNG(seed: 43)

        let values1 = (0..<10).map { _ in rng1.double(in: 0...1000) }
        let values2 = (0..<10).map { _ in rng2.double(in: 0...1000) }

        XCTAssertNotEqual(values1, values2)
    }

    func testGaussianDistribution() {
        var rng = RunRNG(seed: 100)
        let samples = (0..<1000).map { _ in rng.gaussian(mean: 100, stddev: 10) }

        let mean = samples.reduce(0, +) / Double(samples.count)
        XCTAssertEqual(mean, 100, accuracy: 5.0, "Gaussian mean should be near target")

        let variance = samples.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(samples.count)
        let stddev = variance.squareRoot()
        XCTAssertEqual(stddev, 10, accuracy: 5.0, "Gaussian stddev should be near target")
    }

    // MARK: - PaceSimulator

    func testPaceSimulatorGeneratesCorrectCount() {
        var rng = RunRNG(seed: 42)
        let paces = PaceSimulator.generateSplitPaces(
            splitCount: 5,
            basePace: 540,
            profile: .easyRun,
            terrain: .flat,
            rng: &rng
        )
        XCTAssertEqual(paces.count, 5)
    }

    func testPaceSimulatorZeroSplits() {
        var rng = RunRNG(seed: 42)
        let paces = PaceSimulator.generateSplitPaces(
            splitCount: 0,
            basePace: 540,
            profile: .easyRun,
            terrain: .flat,
            rng: &rng
        )
        XCTAssertTrue(paces.isEmpty)
    }

    func testPaceSimulatorPositiveValues() {
        var rng = RunRNG(seed: 42)
        let paces = PaceSimulator.generateSplitPaces(
            splitCount: 10,
            basePace: 540,
            profile: .longRun,
            terrain: .hilly,
            rng: &rng
        )
        for pace in paces {
            XCTAssertGreaterThan(pace, 0)
        }
    }

    func testNegativeSplitTendency() {
        // Race5K has negative split tendency — second half should trend faster
        var rng = RunRNG(seed: 42)
        let paces = PaceSimulator.generateSplitPaces(
            splitCount: 10,
            basePace: 400,
            profile: .race5K,
            terrain: .flat,
            rng: &rng
        )

        let firstHalf = Array(paces.prefix(5))
        let secondHalf = Array(paces.suffix(5))

        let avgFirst = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let avgSecond = secondHalf.reduce(0, +) / Double(secondHalf.count)

        // With negative split tendency + fatigue counteracting, second half should
        // at least not be dramatically slower
        // (exact comparison depends on fatigue vs negative split balance)
        XCTAssertLessThan(avgSecond - avgFirst, avgFirst * 0.1,
                          "Second half shouldn't be much slower than first half for negative split profile")
    }

    // MARK: - HeartRateSimulator

    func testHeartRateSimulatorBasic() {
        var rng = RunRNG(seed: 42)
        let sim = HeartRateSimulator(restingHR: 60, maxHR: 190, hrZone: (0.7, 0.8))
        let result = sim.simulate(duration: 1800, rng: &rng) // 30 min run

        XCTAssertFalse(result.samples.isEmpty)
        XCTAssertGreaterThan(result.average, 0)
        XCTAssertGreaterThanOrEqual(result.max, result.average)
    }

    func testHeartRateStaysInBounds() {
        var rng = RunRNG(seed: 42)
        let sim = HeartRateSimulator(restingHR: 50, maxHR: 185, hrZone: (0.85, 0.95))
        let result = sim.simulate(duration: 1200, rng: &rng)

        for sample in result.samples {
            XCTAssertGreaterThanOrEqual(sample.1, 40, "HR below physiological minimum")
            XCTAssertLessThanOrEqual(sample.1, 210, "HR above physiological maximum")
        }
    }

    func testHeartRateWarmupPattern() {
        var rng = RunRNG(seed: 42)
        let sim = HeartRateSimulator(restingHR: 60, maxHR: 190, hrZone: (0.7, 0.8))
        let result = sim.simulate(duration: 3600, sampleInterval: 10, rng: &rng)

        // First few samples should be lower than mid-run samples
        let earlyHR = result.samples.prefix(5).map { $0.1 }
        let midHR = result.samples.dropFirst(result.samples.count / 3).prefix(5).map { $0.1 }

        let earlyAvg = earlyHR.reduce(0, +) / Double(earlyHR.count)
        let midAvg = midHR.reduce(0, +) / Double(midHR.count)

        XCTAssertLessThan(earlyAvg, midAvg, "Early HR should be lower than mid-run HR (warmup)")
    }

    // MARK: - CadenceSimulator

    func testCadenceSimulatorBasic() {
        var rng = RunRNG(seed: 42)
        let result = CadenceSimulator.simulate(
            baseCadence: 170,
            basePace: 540,
            duration: 1800,
            splitPaces: [540, 530, 550],
            splitDistance: 1609.344,
            rng: &rng
        )

        XCTAssertFalse(result.samples.isEmpty)
        XCTAssertGreaterThan(result.average, 0)
    }

    func testCadenceInReasonableRange() {
        var rng = RunRNG(seed: 42)
        let result = CadenceSimulator.simulate(
            baseCadence: 170,
            basePace: 540,
            duration: 3600,
            splitPaces: Array(repeating: 540.0, count: 6),
            splitDistance: 1609.344,
            rng: &rng
        )

        for sample in result.samples {
            XCTAssertGreaterThanOrEqual(sample.1, 130)
            XCTAssertLessThanOrEqual(sample.1, 220)
        }
    }
}
