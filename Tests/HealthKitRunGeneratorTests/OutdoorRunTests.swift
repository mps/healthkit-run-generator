import XCTest
@testable import HealthKitRunGenerator

final class OutdoorRunTests: XCTestCase {

    let generator = OutdoorRunGenerator()

    // MARK: - Basic Generation

    func testGeneratesOutdoorRun() {
        let config = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(3),
            runType: .outdoor,
            seed: 42
        )
        let run = generator.generate(config: config)

        XCTAssertEqual(run.metrics.totalDistance, config.distance.meters, accuracy: 0.1)
        XCTAssertGreaterThan(run.metrics.totalDuration, 0)
        XCTAssertGreaterThan(run.metrics.averageHeartRate, 0)
        XCTAssertGreaterThan(run.metrics.maxHeartRate, run.metrics.averageHeartRate)
        XCTAssertGreaterThan(run.metrics.averageCadence, 0)
        XCTAssertGreaterThan(run.metrics.totalCalories, 0)
    }

    // MARK: - Route Data

    func testOutdoorRunHasRoutePoints() {
        let config = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(3),
            runType: .outdoor,
            seed: 42
        )
        let run = generator.generate(config: config)

        XCTAssertFalse(run.routePoints.isEmpty, "Outdoor run must have GPS route points")
        XCTAssertGreaterThan(run.routePoints.count, 10)
    }

    func testRoutePointsContinuity() {
        let config = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(2),
            runType: .outdoor,
            seed: 100
        )
        let run = generator.generate(config: config)

        // Consecutive points should be close together (no teleportation)
        for i in 1..<run.routePoints.count {
            let prev = run.routePoints[i - 1]
            let curr = run.routePoints[i]
            let latDiff = abs(curr.latitude - prev.latitude)
            let lonDiff = abs(curr.longitude - prev.longitude)

            // Max ~50m per 3-second sample at fast pace ≈ 0.0005 degrees
            XCTAssertLessThan(latDiff, 0.001,
                              "Route point \(i) jumped too far in latitude")
            XCTAssertLessThan(lonDiff, 0.001,
                              "Route point \(i) jumped too far in longitude")
        }
    }

    func testRouteTimestampsAscending() {
        let config = RunConfiguration(
            profile: .tempoRun,
            fitnessLevel: .advanced,
            distance: .miles(4),
            runType: .outdoor,
            seed: 55
        )
        let run = generator.generate(config: config)

        for i in 1..<run.routePoints.count {
            XCTAssertGreaterThanOrEqual(run.routePoints[i].offset, run.routePoints[i - 1].offset)
        }
    }

    func testCustomStartCoordinate() {
        let nyc = (latitude: 40.7128, longitude: -74.0060)
        let config = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .beginner,
            distance: .miles(1),
            runType: .outdoor,
            seed: 10,
            startCoordinate: nyc
        )
        let run = generator.generate(config: config)

        let first = run.routePoints.first!
        XCTAssertEqual(first.latitude, nyc.latitude, accuracy: 0.01)
        XCTAssertEqual(first.longitude, nyc.longitude, accuracy: 0.01)
    }

    // MARK: - Splits

    func testSplitCountMatchesDistance() {
        let config = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(5),
            runType: .outdoor,
            seed: 42
        )
        let run = generator.generate(config: config)

        XCTAssertEqual(run.metrics.splits.count, 5)
    }

    func testSplitDistancesSumToTotal() {
        let config = RunConfiguration(
            profile: .longRun,
            fitnessLevel: .advanced,
            distance: .miles(10),
            runType: .outdoor,
            terrain: .rolling,
            seed: 77
        )
        let run = generator.generate(config: config)

        let totalSplitDist = run.metrics.splits.reduce(0.0) { $0 + $1.distance }
        XCTAssertEqual(totalSplitDist, run.metrics.totalDistance, accuracy: 1.0)
    }

    func testSplitDurationsSumToTotal() {
        let config = RunConfiguration(
            profile: .tempoRun,
            fitnessLevel: .intermediate,
            distance: .miles(4),
            runType: .outdoor,
            seed: 33
        )
        let run = generator.generate(config: config)

        let totalSplitDur = run.metrics.splits.reduce(0.0) { $0 + $1.duration }
        XCTAssertEqual(totalSplitDur, run.metrics.totalDuration, accuracy: 1.0)
    }

    // MARK: - Heart Rate

    func testHeartRateSamplesExist() {
        let config = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(3),
            runType: .outdoor,
            seed: 42
        )
        let run = generator.generate(config: config)

        XCTAssertFalse(run.heartRateSamples.isEmpty)
    }

    func testHeartRateInPhysiologicalRange() {
        let config = RunConfiguration(
            profile: .race5K,
            fitnessLevel: .advanced,
            distance: .miles(3.1),
            runType: .outdoor,
            seed: 42
        )
        let run = generator.generate(config: config)

        for sample in run.heartRateSamples {
            XCTAssertGreaterThanOrEqual(sample.bpm, 35, "HR too low: \(sample.bpm)")
            XCTAssertLessThanOrEqual(sample.bpm, 210, "HR too high: \(sample.bpm)")
        }
    }

    // MARK: - Cadence

    func testCadenceInReasonableRange() {
        let config = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .beginner,
            distance: .miles(2),
            runType: .outdoor,
            seed: 42
        )
        let run = generator.generate(config: config)

        for sample in run.cadenceSamples {
            XCTAssertGreaterThanOrEqual(sample.spm, 130, "Cadence too low: \(sample.spm)")
            XCTAssertLessThanOrEqual(sample.spm, 220, "Cadence too high: \(sample.spm)")
        }
    }

    // MARK: - Elevation (Terrain Effects)

    func testFlatTerrainMinimalElevation() {
        let config = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(3),
            runType: .outdoor,
            terrain: .flat,
            seed: 42
        )
        let run = generator.generate(config: config)

        // Flat terrain should have relatively low total elevation gain
        XCTAssertLessThan(run.metrics.totalElevationGain, 100,
                          "Flat terrain should have minimal elevation gain")
    }

    func testHillyTerrainMoreElevation() {
        let flatConfig = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(5),
            runType: .outdoor,
            terrain: .flat,
            seed: 42
        )
        let hillyConfig = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(5),
            runType: .outdoor,
            terrain: .hilly,
            seed: 42
        )

        let flatRun = generator.generate(config: flatConfig)
        let hillyRun = generator.generate(config: hillyConfig)

        XCTAssertGreaterThan(hillyRun.metrics.totalElevationGain,
                             flatRun.metrics.totalElevationGain)
    }

    // MARK: - Deterministic (Seeded)

    func testSeedProducesSameOutput() {
        let config = RunConfiguration(
            profile: .tempoRun,
            fitnessLevel: .advanced,
            distance: .miles(5),
            runType: .outdoor,
            seed: 12345
        )

        let run1 = generator.generate(config: config)
        let run2 = generator.generate(config: config)

        XCTAssertEqual(run1.metrics.totalDuration, run2.metrics.totalDuration, accuracy: 0.001)
        XCTAssertEqual(run1.metrics.averageHeartRate, run2.metrics.averageHeartRate, accuracy: 0.001)
        XCTAssertEqual(run1.heartRateSamples.count, run2.heartRateSamples.count)
        XCTAssertEqual(run1.routePoints.count, run2.routePoints.count)
    }

    // MARK: - Convenience Methods

    func testEasyRunFactory() {
        let run = OutdoorRunGenerator.easyRun(miles: 3, level: .intermediate, seed: 42)
        XCTAssertEqual(run.metrics.totalDistance, Distance.miles(3).meters, accuracy: 0.1)
        XCTAssertFalse(run.routePoints.isEmpty)
    }

    func testTempoRunFactory() {
        let run = OutdoorRunGenerator.tempoRun(miles: 4, level: .advanced, seed: 42)
        XCTAssertEqual(run.metrics.totalDistance, Distance.miles(4).meters, accuracy: 0.1)
    }

    func testLongRunFactory() {
        let run = OutdoorRunGenerator.longRun(miles: 10, level: .intermediate, seed: 42)
        XCTAssertEqual(run.metrics.totalDistance, Distance.miles(10).meters, accuracy: 0.1)
        XCTAssertEqual(run.metrics.splits.count, 10)
    }

    // MARK: - Edge Cases

    func testVeryShortRun() {
        let config = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .beginner,
            distance: .miles(0.25),
            runType: .outdoor,
            seed: 42
        )
        let run = generator.generate(config: config)

        XCTAssertEqual(run.metrics.splits.count, 1)
        XCTAssertGreaterThan(run.metrics.totalDuration, 0)
    }

    func testLongDistanceRun() {
        let config = RunConfiguration(
            profile: .raceMarathon,
            fitnessLevel: .advanced,
            distance: .miles(26.2),
            runType: .outdoor,
            terrain: .rolling,
            seed: 42
        )
        let run = generator.generate(config: config)

        XCTAssertEqual(run.metrics.splits.count, 27) // ceil(26.2)
        XCTAssertGreaterThan(run.metrics.totalDuration, 5400) // at least 90 min
    }

    // MARK: - Date Handling

    func testStartAndEndDates() {
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let config = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(3),
            runType: .outdoor,
            startDate: startDate,
            seed: 42
        )
        let run = generator.generate(config: config)

        XCTAssertEqual(run.startDate, startDate)
        XCTAssertEqual(run.endDate.timeIntervalSince(startDate), run.metrics.totalDuration, accuracy: 0.001)
    }
}
