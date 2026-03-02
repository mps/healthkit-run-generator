import XCTest
@testable import HealthKitRunGenerator

final class IndoorRunTests: XCTestCase {

    let generator = IndoorRunGenerator()

    // MARK: - Basic Generation

    func testGeneratesIndoorRun() {
        let config = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(3),
            runType: .indoor,
            seed: 42
        )
        let run = generator.generate(config: config)

        XCTAssertEqual(run.metrics.totalDistance, config.distance.meters, accuracy: 0.1)
        XCTAssertGreaterThan(run.metrics.totalDuration, 0)
        XCTAssertGreaterThan(run.metrics.averageHeartRate, 0)
        XCTAssertGreaterThan(run.metrics.averageCadence, 0)
        XCTAssertGreaterThan(run.metrics.totalCalories, 0)
    }

    // MARK: - No Route Data

    func testIndoorRunHasNoRoutePoints() {
        let config = RunConfiguration(
            profile: .tempoRun,
            fitnessLevel: .advanced,
            distance: .miles(4),
            runType: .indoor,
            seed: 42
        )
        let run = generator.generate(config: config)

        XCTAssertTrue(run.routePoints.isEmpty, "Indoor run must have no GPS route points")
    }

    func testIndoorRunHasZeroElevation() {
        let config = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(3),
            runType: .indoor,
            seed: 42
        )
        let run = generator.generate(config: config)

        XCTAssertEqual(run.metrics.totalElevationGain, 0)
        XCTAssertEqual(run.metrics.totalElevationLoss, 0)

        for split in run.metrics.splits {
            XCTAssertEqual(split.elevationGain, 0)
            XCTAssertEqual(split.elevationLoss, 0)
        }
    }

    // MARK: - Incline Effects

    func testProgressiveInclineSlowsPace() {
        let flatConfig = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(3),
            runType: .indoor,
            inclineProfile: .flat,
            seed: 42
        )
        let inclineConfig = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(3),
            runType: .indoor,
            inclineProfile: .progressive(maxGrade: 5.0),
            seed: 42
        )

        let flatRun = generator.generate(config: flatConfig)
        let inclineRun = generator.generate(config: inclineConfig)

        // Inclined run should take longer (slower pace)
        XCTAssertGreaterThan(inclineRun.metrics.totalDuration, flatRun.metrics.totalDuration)
    }

    func testInclineIncreasesCalories() {
        let flatConfig = RunConfiguration(
            profile: .tempoRun,
            fitnessLevel: .intermediate,
            distance: .miles(3),
            runType: .indoor,
            inclineProfile: .flat,
            seed: 42
        )
        let inclineConfig = RunConfiguration(
            profile: .tempoRun,
            fitnessLevel: .intermediate,
            distance: .miles(3),
            runType: .indoor,
            inclineProfile: .constant(grade: 4.0),
            seed: 42
        )

        let flatRun = generator.generate(config: flatConfig)
        let inclineRun = generator.generate(config: inclineConfig)

        XCTAssertGreaterThan(inclineRun.metrics.totalCalories, flatRun.metrics.totalCalories,
                             "Incline should increase calorie burn")
    }

    // MARK: - Treadmill Pace Consistency

    func testTreadmillPaceMoreConsistent() {
        // Indoor runs should have less pace variation than outdoor
        let indoorConfig = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(5),
            runType: .indoor,
            inclineProfile: .flat,
            seed: 42
        )
        let run = generator.generate(config: indoorConfig)

        let paces = run.metrics.splits.map { $0.pacePerMile }
        guard paces.count > 1 else { return }

        let avgPace = paces.reduce(0, +) / Double(paces.count)
        let maxDeviation = paces.map { abs($0 - avgPace) / avgPace }.max()!

        // Treadmill splits should be within 10% of average
        XCTAssertLessThan(maxDeviation, 0.10,
                          "Treadmill pace variation should be tight")
    }

    // MARK: - Heart Rate

    func testHeartRateSamplesExist() {
        let config = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .beginner,
            distance: .miles(2),
            runType: .indoor,
            seed: 42
        )
        let run = generator.generate(config: config)

        XCTAssertFalse(run.heartRateSamples.isEmpty)
    }

    func testHeartRateInPhysiologicalRange() {
        let config = RunConfiguration(
            profile: .intervalRun,
            fitnessLevel: .intermediate,
            distance: .miles(3),
            runType: .indoor,
            inclineProfile: .interval(highGrade: 4, lowGrade: 0, intervalMinutes: 2),
            seed: 42
        )
        let run = generator.generate(config: config)

        for sample in run.heartRateSamples {
            XCTAssertGreaterThanOrEqual(sample.bpm, 35)
            XCTAssertLessThanOrEqual(sample.bpm, 210)
        }
    }

    // MARK: - Cadence

    func testCadenceInReasonableRange() {
        let config = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .elite,
            distance: .miles(3),
            runType: .indoor,
            seed: 42
        )
        let run = generator.generate(config: config)

        for sample in run.cadenceSamples {
            XCTAssertGreaterThanOrEqual(sample.spm, 130)
            XCTAssertLessThanOrEqual(sample.spm, 220)
        }
    }

    // MARK: - Splits

    func testSplitDistancesSumToTotal() {
        let config = RunConfiguration(
            profile: .tempoRun,
            fitnessLevel: .advanced,
            distance: .miles(5),
            runType: .indoor,
            seed: 42
        )
        let run = generator.generate(config: config)

        let totalSplitDist = run.metrics.splits.reduce(0.0) { $0 + $1.distance }
        XCTAssertEqual(totalSplitDist, run.metrics.totalDistance, accuracy: 1.0)
    }

    func testSplitDurationsSumToTotal() {
        let config = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(3),
            runType: .indoor,
            seed: 42
        )
        let run = generator.generate(config: config)

        let totalSplitDur = run.metrics.splits.reduce(0.0) { $0 + $1.duration }
        XCTAssertEqual(totalSplitDur, run.metrics.totalDuration, accuracy: 1.0)
    }

    // MARK: - Deterministic

    func testSeedProducesSameOutput() {
        let config = RunConfiguration(
            profile: .tempoRun,
            fitnessLevel: .advanced,
            distance: .miles(4),
            runType: .indoor,
            inclineProfile: .progressive(maxGrade: 3.0),
            seed: 99999
        )

        let run1 = generator.generate(config: config)
        let run2 = generator.generate(config: config)

        XCTAssertEqual(run1.metrics.totalDuration, run2.metrics.totalDuration, accuracy: 0.001)
        XCTAssertEqual(run1.metrics.averageHeartRate, run2.metrics.averageHeartRate, accuracy: 0.001)
        XCTAssertEqual(run1.heartRateSamples.count, run2.heartRateSamples.count)
    }

    // MARK: - Convenience Methods

    func testEasyRunFactory() {
        let run = IndoorRunGenerator.easyRun(miles: 3, level: .beginner, seed: 42)
        XCTAssertEqual(run.metrics.totalDistance, Distance.miles(3).meters, accuracy: 0.1)
        XCTAssertTrue(run.routePoints.isEmpty)
    }

    func testTempoRunFactory() {
        let run = IndoorRunGenerator.tempoRun(miles: 4, level: .advanced, seed: 42)
        XCTAssertEqual(run.metrics.totalDistance, Distance.miles(4).meters, accuracy: 0.1)
    }

    func testIntervalRunFactory() {
        let run = IndoorRunGenerator.intervalRun(miles: 3, level: .intermediate, seed: 42)
        XCTAssertEqual(run.metrics.totalDistance, Distance.miles(3).meters, accuracy: 0.1)
    }

    // MARK: - Edge Cases

    func testVeryShortTreadmillRun() {
        let config = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .beginner,
            distance: .miles(0.25),
            runType: .indoor,
            seed: 42
        )
        let run = generator.generate(config: config)

        XCTAssertEqual(run.metrics.splits.count, 1)
        XCTAssertGreaterThan(run.metrics.totalDuration, 0)
        XCTAssertTrue(run.routePoints.isEmpty)
    }
}
