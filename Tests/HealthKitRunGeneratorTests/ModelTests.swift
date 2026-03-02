import XCTest
@testable import HealthKitRunGenerator

final class ModelTests: XCTestCase {

    // MARK: - Distance

    func testDistanceMilesConversion() {
        let d = Distance.miles(5)
        XCTAssertEqual(d.miles, 5.0, accuracy: 0.001)
        XCTAssertEqual(d.kilometers, 8.04672, accuracy: 0.01)
        XCTAssertEqual(d.meters, 8046.72, accuracy: 0.1)
    }

    func testDistanceKilometersConversion() {
        let d = Distance.kilometers(10)
        XCTAssertEqual(d.kilometers, 10.0, accuracy: 0.001)
        XCTAssertEqual(d.miles, 6.21371, accuracy: 0.01)
    }

    func testDistanceMetersConversion() {
        let d = Distance.meters(1609.344)
        XCTAssertEqual(d.miles, 1.0, accuracy: 0.001)
    }

    // MARK: - FitnessLevel

    func testFitnessLevelRangesOrdered() {
        // Elite should have lower resting HR than beginner
        XCTAssertLessThan(FitnessLevel.elite.restingHeartRate.upperBound,
                          FitnessLevel.beginner.restingHeartRate.lowerBound)

        // Elite should be faster (lower pace numbers) than beginner
        XCTAssertLessThan(FitnessLevel.elite.easyPacePerMile.upperBound,
                          FitnessLevel.beginner.easyPacePerMile.lowerBound)

        // Cadence should generally increase with fitness
        XCTAssertLessThanOrEqual(FitnessLevel.beginner.cadenceRange.lowerBound,
                                 FitnessLevel.elite.cadenceRange.lowerBound)
    }

    func testAllFitnessLevelsHaveValidRanges() {
        for level in FitnessLevel.allCases {
            XCTAssertGreaterThan(level.maxHeartRate.lowerBound, 0)
            XCTAssertGreaterThan(level.restingHeartRate.lowerBound, 0)
            XCTAssertLessThan(level.restingHeartRate.upperBound, level.maxHeartRate.lowerBound)
            XCTAssertGreaterThan(level.easyPacePerMile.lowerBound, 0)
            XCTAssertGreaterThan(level.tempoPacePerMile.lowerBound, 0)
            // Tempo should be faster than easy
            XCTAssertLessThan(level.tempoPacePerMile.lowerBound, level.easyPacePerMile.upperBound)
        }
    }

    // MARK: - RunProfile

    func testRunProfileHeartRateZones() {
        for profile in RunProfile.allCases {
            let zone = profile.heartRateZone
            XCTAssertGreaterThan(zone.lower, 0)
            XCTAssertLessThanOrEqual(zone.lower, zone.upper)
            XCTAssertLessThanOrEqual(zone.upper, 1.0)
        }
    }

    func testRunProfileDurationRanges() {
        // Marathon should take longer than 5K
        XCTAssertGreaterThan(RunProfile.raceMarathon.durationRange.lowerBound,
                             RunProfile.race5K.durationRange.upperBound)
    }

    func testNegativeSplitProfiles() {
        XCTAssertTrue(RunProfile.race5K.negativeSplitTendency)
        XCTAssertTrue(RunProfile.raceHalfMarathon.negativeSplitTendency)
        XCTAssertFalse(RunProfile.easyRun.negativeSplitTendency)
        XCTAssertFalse(RunProfile.longRun.negativeSplitTendency)
    }

    // MARK: - TerrainType

    func testTerrainElevationOrdering() {
        XCTAssertLessThan(TerrainType.flat.maxElevationGainPerMile,
                          TerrainType.rolling.maxElevationGainPerMile)
        XCTAssertLessThan(TerrainType.rolling.maxElevationGainPerMile,
                          TerrainType.hilly.maxElevationGainPerMile)
    }

    func testTerrainPaceFactor() {
        XCTAssertEqual(TerrainType.flat.uphillPaceFactor, 1.0)
        XCTAssertGreaterThan(TerrainType.rolling.uphillPaceFactor, 1.0)
        XCTAssertGreaterThan(TerrainType.hilly.uphillPaceFactor,
                             TerrainType.rolling.uphillPaceFactor)
    }

    // MARK: - InclineProfile

    func testFlatInclineAlwaysZero() {
        let profile = InclineProfile.flat
        XCTAssertEqual(profile.grade(atFraction: 0), 0)
        XCTAssertEqual(profile.grade(atFraction: 0.5), 0)
        XCTAssertEqual(profile.grade(atFraction: 1.0), 0)
    }

    func testProgressiveInclineRises() {
        let profile = InclineProfile.progressive(maxGrade: 5.0)
        XCTAssertEqual(profile.grade(atFraction: 0), 0, accuracy: 0.01)
        XCTAssertEqual(profile.grade(atFraction: 0.5), 2.5, accuracy: 0.01)
        XCTAssertEqual(profile.grade(atFraction: 1.0), 5.0, accuracy: 0.01)
    }

    func testConstantIncline() {
        let profile = InclineProfile.constant(grade: 3.0)
        XCTAssertEqual(profile.grade(atFraction: 0), 3.0)
        XCTAssertEqual(profile.grade(atFraction: 0.5), 3.0)
        XCTAssertEqual(profile.grade(atFraction: 1.0), 3.0)
    }

    func testInclineClampsFraction() {
        let profile = InclineProfile.progressive(maxGrade: 10.0)
        // Values outside 0-1 should be clamped
        XCTAssertEqual(profile.grade(atFraction: -0.5), 0, accuracy: 0.01)
        XCTAssertEqual(profile.grade(atFraction: 1.5), 10.0, accuracy: 0.01)
    }

    // MARK: - SplitData

    func testSplitPaceCalculation() {
        let split = SplitData(
            index: 0,
            distance: 1609.344, // 1 mile
            duration: 600,      // 10 minutes
            averageHeartRate: 150,
            averageCadence: 170
        )
        XCTAssertEqual(split.pacePerMile, 600, accuracy: 0.1) // 10:00/mi
        XCTAssertEqual(split.pacePerKilometer, 372.82, accuracy: 1.0) // ~6:13/km
    }

    func testSplitZeroDistanceHandled() {
        let split = SplitData(
            index: 0,
            distance: 0,
            duration: 60,
            averageHeartRate: 150,
            averageCadence: 170
        )
        XCTAssertEqual(split.pacePerMile, 0)
        XCTAssertEqual(split.pacePerKilometer, 0)
    }

    // MARK: - RunMetrics

    func testRunMetricsPaceCalculation() {
        let metrics = RunMetrics(
            totalDistance: 8046.72, // 5 miles
            totalDuration: 2700,    // 45 minutes
            averageHeartRate: 155,
            maxHeartRate: 175,
            averageCadence: 170
        )
        XCTAssertEqual(metrics.averagePacePerMile, 540, accuracy: 1.0) // 9:00/mi
    }

    // MARK: - RunConfiguration

    func testConfigurationDefaults() {
        let config = RunConfiguration(
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(3)
        )
        XCTAssertEqual(config.runType, .outdoor)
        XCTAssertEqual(config.terrain, .flat)
        XCTAssertNil(config.seed)
        XCTAssertNil(config.startCoordinate)
    }
}
