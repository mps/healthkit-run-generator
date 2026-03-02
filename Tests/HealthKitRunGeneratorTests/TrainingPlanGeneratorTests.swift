import XCTest
@testable import HealthKitRunGenerator

final class TrainingPlanGeneratorTests: XCTestCase {

    let generator = TrainingPlanGenerator()

    // MARK: - Basic Plan Generation

    func testGenerates4WeekPlan() {
        let plan = generator.generate(
            fitnessLevel: .intermediate,
            goalDistance: .halfMarathon,
            baseSeed: 42
        )
        XCTAssertEqual(plan.weeks, 4)
        XCTAssertEqual(plan.fitnessLevel, .intermediate)
        XCTAssertEqual(plan.goalDistance, .halfMarathon)
    }

    func testPlanHasRunsEveryWeek() {
        let plan = generator.generate(
            fitnessLevel: .intermediate,
            goalDistance: .tenK,
            baseSeed: 1
        )
        for week in 0..<4 {
            let weekRuns = plan.runsForWeek(week)
            XCTAssertGreaterThanOrEqual(weekRuns.count, 3,
                                        "Week \(week + 1) should have at least 3 runs")
            XCTAssertLessThanOrEqual(weekRuns.count, 6,
                                     "Week \(week + 1) should have at most 6 runs")
        }
    }

    func testAllGoalDistancesGenerate() {
        for goal in GoalDistance.allCases {
            for level in FitnessLevel.allCases {
                let plan = generator.generate(
                    fitnessLevel: level,
                    goalDistance: goal,
                    baseSeed: 100
                )
                XCTAssertGreaterThan(plan.runs.count, 0,
                                     "\(goal.rawValue)/\(level.rawValue) should generate runs")
                XCTAssertGreaterThan(plan.totalMileage, 0)
            }
        }
    }

    // MARK: - Periodization

    func testWeek4IsRecovery() {
        let plan = generator.generate(
            fitnessLevel: .advanced,
            goalDistance: .marathon,
            baseSeed: 42
        )
        let week3Miles = plan.weeklyMileage[2] // Peak week
        let week4Miles = plan.weeklyMileage[3] // Recovery week

        XCTAssertLessThan(week4Miles, week3Miles,
                          "Recovery week (4) should have less mileage than peak week (3)")
    }

    func testWeek3IsPeak() {
        let plan = generator.generate(
            fitnessLevel: .intermediate,
            goalDistance: .halfMarathon,
            baseSeed: 42
        )
        let week1Miles = plan.weeklyMileage[0]
        let week3Miles = plan.weeklyMileage[2]

        XCTAssertGreaterThan(week3Miles, week1Miles,
                             "Peak week (3) should have more mileage than base week (1)")
    }

    func testMileageProgression() {
        let plan = generator.generate(
            fitnessLevel: .intermediate,
            goalDistance: .tenK,
            baseSeed: 42
        )
        // Weeks 1-3 should show progression
        XCTAssertLessThanOrEqual(plan.weeklyMileage[0], plan.weeklyMileage[2],
                                 "Mileage should build from week 1 to week 3")
    }

    // MARK: - Run Type Distribution

    func testPlanIncludesVariedRunTypes() {
        let plan = generator.generate(
            fitnessLevel: .advanced,
            goalDistance: .halfMarathon,
            baseSeed: 42
        )

        let profiles = Set(plan.runs.map { $0.run.configuration.profile })
        XCTAssertTrue(profiles.contains(.easyRun), "Plan should include easy runs")
        XCTAssertTrue(profiles.contains(.longRun), "Plan should include long runs")
        // Advanced+ should have quality sessions
        XCTAssertGreaterThan(profiles.count, 2, "Advanced plans should have varied run types")
    }

    func testIntensityDistribution() {
        let plan = generator.generate(
            fitnessLevel: .intermediate,
            goalDistance: .tenK,
            baseSeed: 42
        )
        let dist = plan.intensityDistribution

        // Easy runs should be majority (polarized training)
        XCTAssertGreaterThan(dist.easy, 0.3,
                             "Easy runs should be at least 30% of total runs")

        // Long runs should exist
        XCTAssertGreaterThan(dist.longRun, 0,
                             "Plan should include long runs")
    }

    // MARK: - Rest Days

    func testPlanHasRestDays() {
        let plan = generator.generate(
            fitnessLevel: .beginner,
            goalDistance: .fiveK,
            baseSeed: 42
        )
        XCTAssertGreaterThan(plan.restDays.count, 0, "Plan should include rest days")
        // 28 days - (4 runs/week * 4 weeks) = 12 rest days for beginner
        XCTAssertGreaterThanOrEqual(plan.restDays.count, 8,
                                     "Beginner should have plenty of rest days")
    }

    func testEliteHasFewerRestDays() {
        let beginnerPlan = generator.generate(
            fitnessLevel: .beginner,
            goalDistance: .tenK,
            baseSeed: 42
        )
        let elitePlan = generator.generate(
            fitnessLevel: .elite,
            goalDistance: .tenK,
            baseSeed: 42
        )
        XCTAssertGreaterThan(beginnerPlan.restDays.count, elitePlan.restDays.count,
                             "Beginners should have more rest days than elite")
    }

    // MARK: - Determinism

    func testSeedProducesSamePlan() {
        let plan1 = generator.generate(
            fitnessLevel: .intermediate,
            goalDistance: .halfMarathon,
            baseSeed: 12345
        )
        let plan2 = generator.generate(
            fitnessLevel: .intermediate,
            goalDistance: .halfMarathon,
            baseSeed: 12345
        )

        XCTAssertEqual(plan1.runs.count, plan2.runs.count)
        XCTAssertEqual(plan1.totalMileage, plan2.totalMileage, accuracy: 0.001)

        for i in 0..<plan1.runs.count {
            XCTAssertEqual(plan1.runs[i].run.metrics.totalDuration,
                           plan2.runs[i].run.metrics.totalDuration, accuracy: 0.001)
            XCTAssertEqual(plan1.runs[i].dayIndex, plan2.runs[i].dayIndex)
        }
    }

    func testDifferentSeedsProduceDifferentPlans() {
        let plan1 = generator.generate(
            fitnessLevel: .intermediate,
            goalDistance: .tenK,
            baseSeed: 1
        )
        let plan2 = generator.generate(
            fitnessLevel: .intermediate,
            goalDistance: .tenK,
            baseSeed: 999
        )

        // Same structure but different durations
        let durations1 = plan1.runs.map { $0.run.metrics.totalDuration }
        let durations2 = plan2.runs.map { $0.run.metrics.totalDuration }
        XCTAssertNotEqual(durations1, durations2)
    }

    // MARK: - Plan Integrity

    func testRunDayIndicesAreValid() {
        let plan = generator.generate(
            fitnessLevel: .intermediate,
            goalDistance: .halfMarathon,
            baseSeed: 42
        )
        for run in plan.runs {
            XCTAssertGreaterThanOrEqual(run.dayIndex, 0)
            XCTAssertLessThan(run.dayIndex, 28)
        }
    }

    func testRunsAreSortedByDay() {
        let plan = generator.generate(
            fitnessLevel: .advanced,
            goalDistance: .marathon,
            baseSeed: 42
        )
        for i in 1..<plan.runs.count {
            XCTAssertGreaterThanOrEqual(plan.runs[i].dayIndex, plan.runs[i - 1].dayIndex)
        }
    }

    func testEachRunHasPositiveMetrics() {
        let plan = generator.generate(
            fitnessLevel: .intermediate,
            goalDistance: .tenK,
            baseSeed: 42
        )
        for sr in plan.runs {
            XCTAssertGreaterThan(sr.run.metrics.totalDistance, 0)
            XCTAssertGreaterThan(sr.run.metrics.totalDuration, 0)
            XCTAssertGreaterThan(sr.run.metrics.averageHeartRate, 0)
            XCTAssertGreaterThan(sr.run.metrics.averageCadence, 0)
            XCTAssertFalse(sr.purpose.isEmpty, "Each run should have a purpose")
        }
    }

    func testWeekPropertyIsCorrect() {
        let plan = generator.generate(
            fitnessLevel: .intermediate,
            goalDistance: .fiveK,
            baseSeed: 42
        )
        for sr in plan.runs {
            let expectedWeek = (sr.dayIndex / 7) + 1
            XCTAssertEqual(sr.week, expectedWeek)
        }
    }

    // MARK: - Goal Distance Scaling

    func testMarathonPlanHasMoreMileage() {
        let fiveKPlan = generator.generate(
            fitnessLevel: .intermediate,
            goalDistance: .fiveK,
            baseSeed: 42
        )
        let marathonPlan = generator.generate(
            fitnessLevel: .intermediate,
            goalDistance: .marathon,
            baseSeed: 42
        )
        XCTAssertGreaterThan(marathonPlan.totalMileage, fiveKPlan.totalMileage,
                             "Marathon plan should have more total mileage than 5K plan")
    }

    // MARK: - Description

    func testPlanDescription() {
        let plan = generator.generate(
            fitnessLevel: .intermediate,
            goalDistance: .halfMarathon,
            baseSeed: 42
        )
        let desc = plan.description
        XCTAssertTrue(desc.contains("Half Marathon"))
        XCTAssertTrue(desc.contains("intermediate"))
        XCTAssertTrue(desc.contains("Week 1"))
        XCTAssertTrue(desc.contains("Week 4"))
    }

    // MARK: - Indoor Plan

    func testIndoorTrainingPlan() {
        let plan = generator.generate(
            fitnessLevel: .intermediate,
            goalDistance: .tenK,
            baseSeed: 42,
            runType: .indoor
        )
        for sr in plan.runs {
            XCTAssertEqual(sr.run.configuration.runType, .indoor)
            XCTAssertTrue(sr.run.routePoints.isEmpty)
        }
    }
}
