import XCTest
@testable import HealthKitRunGenerator

final class BatchRunGeneratorTests: XCTestCase {

    let generator = BatchRunGenerator()

    // MARK: - Seed Range Generation

    func testGeneratesCorrectCountFromSeedRange() {
        let runs = generator.generate(
            seedRange: 1...10,
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(3)
        )
        XCTAssertEqual(runs.count, 10)
    }

    func testSeedRangeProducesDeterministicOutput() {
        let runs1 = generator.generate(
            seedRange: 1...5,
            profile: .tempoRun,
            fitnessLevel: .advanced,
            distance: .miles(4)
        )
        let runs2 = generator.generate(
            seedRange: 1...5,
            profile: .tempoRun,
            fitnessLevel: .advanced,
            distance: .miles(4)
        )

        for i in 0..<5 {
            XCTAssertEqual(runs1[i].metrics.totalDuration, runs2[i].metrics.totalDuration, accuracy: 0.001,
                           "Run \(i) should be identical across generations")
            XCTAssertEqual(runs1[i].metrics.averageHeartRate, runs2[i].metrics.averageHeartRate, accuracy: 0.001)
        }
    }

    func testDifferentSeedsProduceDifferentRuns() {
        let runs = generator.generate(
            seedRange: 1...5,
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(3)
        )

        // Not all durations should be identical (different seeds → different output)
        let durations = Set(runs.map { Int($0.metrics.totalDuration) })
        XCTAssertGreaterThan(durations.count, 1, "Different seeds should produce different durations")
    }

    func testSingleSeedRange() {
        let runs = generator.generate(
            seedRange: 42...42,
            profile: .easyRun,
            fitnessLevel: .beginner,
            distance: .miles(2)
        )
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs[0].configuration.seed, 42)
    }

    // MARK: - Configuration Profile Generation

    func testProfileGeneratesExpectedRunCount() {
        let runs = generator.generate(
            count: 1,
            configProfile: .easyWeek,
            fitnessLevel: .intermediate,
            weeklyMileage: 20
        )
        // easyWeek has 5 run templates
        XCTAssertEqual(runs.count, 5)
    }

    func testMultipleCyclesMultipliesCount() {
        let runs = generator.generate(
            count: 3,
            configProfile: .recoveryWeek,
            fitnessLevel: .beginner,
            weeklyMileage: 12
        )
        // recoveryWeek has 4 templates × 3 cycles
        XCTAssertEqual(runs.count, 12)
    }

    func testProfileMileageDistribution() {
        let weeklyMileage = 30.0
        let runs = generator.generate(
            count: 1,
            configProfile: .balanced,
            fitnessLevel: .intermediate,
            weeklyMileage: weeklyMileage
        )

        let totalMiles = runs.reduce(0.0) { $0 + $1.metrics.totalDistance / 1609.344 }
        // Total should be close to weekly mileage (fractions sum to ~1.0)
        XCTAssertEqual(totalMiles, weeklyMileage, accuracy: weeklyMileage * 0.15,
                       "Total batch mileage should approximate weekly target")
    }

    func testAllProfilesGenerate() {
        for profile in ConfigurationProfile.allCases {
            let runs = generator.generate(
                count: 1,
                configProfile: profile,
                fitnessLevel: .intermediate,
                weeklyMileage: 20
            )
            XCTAssertGreaterThan(runs.count, 0, "\(profile.rawValue) should generate runs")
            for run in runs {
                XCTAssertGreaterThan(run.metrics.totalDuration, 0)
                XCTAssertGreaterThan(run.metrics.totalDistance, 0)
            }
        }
    }

    // MARK: - Filtering

    func testFilterByMinDistance() {
        let filter = BatchRunGenerator.FilterOptions(minDistanceMiles: 4.0)
        let runs = generator.generate(
            seedRange: 1...20,
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(3),
            filter: filter
        )
        // All runs are 3 miles, so filter should exclude all
        XCTAssertEqual(runs.count, 0)
    }

    func testFilterByMaxDistance() {
        let filter = BatchRunGenerator.FilterOptions(maxDistanceMiles: 10.0)
        let runs = generator.generate(
            seedRange: 1...5,
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(3),
            filter: filter
        )
        // All runs are 3 miles, should pass the filter
        XCTAssertEqual(runs.count, 5)
    }

    func testFilterByRunType() {
        let filter = BatchRunGenerator.FilterOptions(runType: .indoor)
        let runs = generator.generate(
            seedRange: 1...5,
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(3),
            runType: .outdoor,
            filter: filter
        )
        // Outdoor runs filtered for indoor → empty
        XCTAssertEqual(runs.count, 0)
    }

    func testFilterByProfile() {
        let filter = BatchRunGenerator.FilterOptions(profiles: [.tempoRun, .intervalRun])
        let runs = generator.generate(
            count: 1,
            configProfile: .balanced,
            fitnessLevel: .intermediate,
            weeklyMileage: 20,
            filter: filter
        )
        // Only tempo and interval runs should survive
        for run in runs {
            XCTAssertTrue(
                run.configuration.profile == .tempoRun || run.configuration.profile == .intervalRun,
                "Expected tempo or interval, got \(run.configuration.profile.rawValue)"
            )
        }
    }

    func testFilterWithNoConstraintsPassesAll() {
        let filter = BatchRunGenerator.FilterOptions()
        let runs = generator.generate(
            seedRange: 1...5,
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(3),
            filter: filter
        )
        XCTAssertEqual(runs.count, 5)
    }

    // MARK: - JSON Export

    func testJSONExportContainsExpectedKeys() {
        let runs = generator.generate(
            seedRange: 1...2,
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(3)
        )
        let json = BatchRunGenerator.toJSON(runs)

        XCTAssertEqual(json.count, 2)
        let first = json[0]
        XCTAssertNotNil(first["profile"])
        XCTAssertNotNil(first["fitnessLevel"])
        XCTAssertNotNil(first["distance_miles"])
        XCTAssertNotNil(first["duration_seconds"])
        XCTAssertNotNil(first["average_pace_per_mile"])
        XCTAssertNotNil(first["average_heart_rate"])
        XCTAssertNotNil(first["splits"])
        XCTAssertNotNil(first["start_date"])
    }

    func testJSONDataExport() {
        let runs = generator.generate(
            seedRange: 1...3,
            profile: .tempoRun,
            fitnessLevel: .advanced,
            distance: .miles(4)
        )
        let data = BatchRunGenerator.toJSONData(runs)
        XCTAssertNotNil(data)

        // Verify it's valid JSON
        if let data {
            let parsed = try? JSONSerialization.jsonObject(with: data)
            XCTAssertNotNil(parsed)
            XCTAssertTrue(parsed is [[String: Any]])
        }
    }

    // MARK: - Indoor Batch

    func testIndoorBatchGeneration() {
        let runs = generator.generate(
            seedRange: 1...5,
            profile: .tempoRun,
            fitnessLevel: .advanced,
            distance: .miles(4),
            runType: .indoor
        )
        XCTAssertEqual(runs.count, 5)
        for run in runs {
            XCTAssertTrue(run.routePoints.isEmpty, "Indoor runs should have no route")
            XCTAssertEqual(run.configuration.runType, .indoor)
        }
    }

    // MARK: - Date Progression

    func testRunDatesProgress() {
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let runs = generator.generate(
            seedRange: 1...5,
            profile: .easyRun,
            fitnessLevel: .intermediate,
            distance: .miles(3),
            startDate: startDate
        )

        for i in 1..<runs.count {
            XCTAssertGreaterThan(runs[i].startDate, runs[i - 1].startDate,
                                 "Run dates should progress forward")
        }
    }
}
